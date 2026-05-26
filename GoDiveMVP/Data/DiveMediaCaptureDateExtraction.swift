import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif

/// Resolves when dive media was captured — prefers camera / file metadata over the Photos library date for images;
/// for library videos, **`PHAsset`** dates usually match the Photos app (picker temp copies often strip QuickTime tags).
enum DiveMediaCaptureDateExtraction: Sendable {

    /// First non-**`nil`** date in priority order.
    nonisolated static func firstCaptureDate(_ candidates: [Date?]) -> Date? {
        for candidate in candidates where candidate != nil {
            return candidate
        }
        return nil
    }

    // MARK: - Images (EXIF + container metadata)

    /// Reads capture-related timestamps from image bytes (before JPEG re-encode strips metadata).
    nonisolated static func captureDateFromImageData(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let offset = exifOffsetSeconds(
            from: exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String
                ?? exif?[kCGImagePropertyExifOffsetTimeDigitized] as? String
        )

        let exifOriginal = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            .flatMap { parseExifDateTime($0, offsetSeconds: offset) }
        let exifDigitized = (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            .flatMap { parseExifDateTime($0, offsetSeconds: offset) }
        let tiffDate = (tiff?[kCGImagePropertyTIFFDateTime] as? String)
            .flatMap { parseExifDateTime($0, offsetSeconds: offset) }
        let iptcDate = captureDateFromIPTC(iptc)
        let gpsDate = captureDateFromGPS(gps)

        return firstCaptureDate([exifOriginal, exifDigitized, tiffDate, iptcDate, gpsDate])
    }

    static func resolveImageCaptureDate(data: Data, photosLocalIdentifier: String?) async -> Date? {
        let cameraOrFile = captureDateFromImageData(data)
        let library = await photosLibraryCaptureDate(localIdentifier: photosLocalIdentifier)
        return firstCaptureDate([cameraOrFile, library])
    }

    // MARK: - Video (Photos library + file metadata)

    static func resolveVideoCaptureDate(fileURL: URL, photosLocalIdentifier: String?) async -> Date? {
        let library = await photosLibraryCaptureDate(localIdentifier: photosLocalIdentifier)
        let fileDate = await captureDateFromVideoFile(fileURL)
        return firstCaptureDate([library, fileDate])
    }

    #if canImport(AVFoundation)
    private static func captureDateFromVideoFile(_ url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)

        if let creationItem = try? await asset.load(.creationDate),
           let date = try? await creationItem.load(.dateValue) {
            return date
        }

        let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
        let commonDates = await datesFromMetadataItems(commonMetadata)
        if let first = firstCaptureDate(commonDates) {
            return first
        }

        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        for format in formats {
            guard let metadata = try? await asset.loadMetadata(for: format) else { continue }
            let dates = await datesFromMetadataItems(metadata)
            if let first = firstCaptureDate(dates) {
                return first
            }
        }
        return nil
    }

    private static func datesFromMetadataItems(_ items: [AVMetadataItem]) async -> [Date?] {
        var dates: [Date?] = []
        for item in items {
            if let date = await dateFromMetadataItem(item) {
                dates.append(date)
            }
        }
        return dates
    }

    private static func dateFromMetadataItem(_ item: AVMetadataItem) async -> Date? {
        if let date = try? await item.load(.dateValue) {
            return date
        }
        if let string = try? await item.load(.stringValue),
           let parsed = parseMetadataDateString(string) {
            return parsed
        }
        return nil
    }
    #else
    private static func captureDateFromVideoFile(_ url: URL) async -> Date? {
        _ = url
        return nil
    }
    #endif

    // MARK: - Photos library

    static func photosLibraryCaptureDate(localIdentifier: String?) async -> Date? {
        #if canImport(Photos)
        guard let identifier = localIdentifier else { return nil }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }

        return await MainActor.run {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = assets.firstObject else { return nil }
            return firstCaptureDate([
                asset.creationDate,
                asset.modificationDate,
            ])
        }
        #else
        _ = localIdentifier
        return nil
        #endif
    }

    // MARK: - IPTC / GPS

    nonisolated static func captureDateFromIPTC(_ iptc: [CFString: Any]?) -> Date? {
        guard let iptc else { return nil }
        let dateCreated = parseIPTCDateTime(
            date: iptc[kCGImagePropertyIPTCDateCreated] as? String,
            time: iptc[kCGImagePropertyIPTCTimeCreated] as? String
        )
        if let dateCreated {
            return dateCreated
        }
        return parseIPTCDateTime(
            date: iptc[kCGImagePropertyIPTCDigitalCreationDate] as? String,
            time: iptc[kCGImagePropertyIPTCDigitalCreationTime] as? String
        )
    }

    nonisolated static func captureDateFromGPS(_ gps: [CFString: Any]?) -> Date? {
        guard let gps else { return nil }
        guard let dateStamp = gps[kCGImagePropertyGPSDateStamp] as? String else { return nil }
        let timeStamp = gps[kCGImagePropertyGPSTimeStamp] as? String
        if let timeStamp, !timeStamp.isEmpty {
            return parseExifDateTime("\(dateStamp) \(timeStamp)", offsetSeconds: nil)
        }
        return parseMetadataDateString(dateStamp)
    }

    nonisolated static func parseIPTCDateTime(date: String?, time: String?) -> Date? {
        guard let date, !date.isEmpty else { return nil }
        let trimmedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = time?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedDate.count == 8, trimmedTime.count == 6,
           let year = Int(trimmedDate.prefix(4)),
           let month = Int(trimmedDate.dropFirst(4).prefix(2)),
           let day = Int(trimmedDate.suffix(2)),
           let hour = Int(trimmedTime.prefix(2)),
           let minute = Int(trimmedTime.dropFirst(2).prefix(2)),
           let second = Int(trimmedTime.suffix(2)) {
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = captureDateFallbackTimeZone
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = second
            return components.date
        }

        if trimmedTime.isEmpty {
            return parseMetadataDateString(trimmedDate)
        }

        let combined = "\(trimmedDate) \(trimmedTime)"
        if let parsed = parseExifDateTime(combined, offsetSeconds: nil) {
            return parsed
        }
        return parseMetadataDateString(combined)
    }

    // MARK: - Date parsing

    /// When EXIF/IPTC omit a zone, parse as UTC wall time (avoids **`TimeZone.current`** on the main actor).
    nonisolated static var captureDateFallbackTimeZone: TimeZone {
        TimeZone(secondsFromGMT: 0) ?? .gmt
    }

    /// EXIF **`yyyy:MM:dd HH:mm:ss`** with optional **`±HH:MM`** offset from **`OffsetTimeOriginal`**.
    nonisolated static func parseExifDateTime(_ raw: String, offsetSeconds: Int?) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let offsetSeconds {
            formatter.timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? captureDateFallbackTimeZone
        } else {
            formatter.timeZone = captureDateFallbackTimeZone
        }
        return formatter.date(from: trimmed)
    }

    /// ISO-8601 and common QuickTime / file date strings.
    nonisolated static func parseMetadataDateString(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) {
            return date
        }

        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy:MM:dd HH:mm:ss",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for pattern in patterns {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    nonisolated static func exifOffsetSeconds(from offsetTime: String?) -> Int? {
        guard let offsetTime else { return nil }
        let trimmed = offsetTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let sign: Int
        switch trimmed.first {
        case "+": sign = 1
        case "-": sign = -1
        default: return nil
        }

        let body = trimmed.dropFirst()
        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        guard let hours = Int(parts[0]) else { return nil }
        let minutes = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return sign * (hours * 3600 + minutes * 60)
    }
}
