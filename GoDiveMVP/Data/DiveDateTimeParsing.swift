import Foundation

/// Parses dive start / log timestamps from import strings into a UTC instant plus optional fixed offset for display.
enum DiveDateTimeParsing: Sendable {

    struct Result: Equatable, Sendable {
        /// Absolute instant (UTC storage).
        var instant: Date
        /// Seconds east of UTC when known (from **`Z`**, RFC 3339 offset, or UDDF site **`timezone`**).
        var timeZoneOffsetSeconds: Int?
    }

    /// UDDF **`informationbeforedive/datetime`** with optional linked-site **`geography/timezone`** (hours from UTC).
    ///
    /// Per UDDF / ISO 8601: **`Z`** or a **`±HH:MM`** suffix on **`datetime`** define the instant. A naive
    /// **`datetime`** (no zone) with a site **`timezone`** or inferable site coordinates is **dive-local wall time**.
    /// Naive without any site offset falls back to **UTC** wall time (corrected after import when coordinates exist).
    nonisolated static func parseUddfDateTime(
        _ raw: String,
        siteTimeZoneHours: Double? = nil,
        siteLatitude: Double? = nil,
        siteLongitude: Double? = nil,
        siteLocationName: String? = nil,
        macDiveNaiveSemantics: UddfMacDiveWatchDatetimeSemantics? = nil
    ) -> Result? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let offset = explicitOffsetSeconds(in: trimmed), let instant = parseISOInstant(trimmed) {
            return Result(instant: instant, timeZoneOffsetSeconds: offset)
        }

        if let instant = parseISOInstant(trimmed),
           trimmed.last?.uppercased() == "Z" {
            return Result(instant: instant, timeZoneOffsetSeconds: 0)
        }

        if macDiveNaiveSemantics == .utcWallClock,
           let instant = parseNaiveWallTimeAsUtcInstant(trimmed) {
            return Result(instant: instant, timeZoneOffsetSeconds: nil)
        }

        if let effectiveHours = resolvedSiteTimeZoneHours(
            xmlHours: siteTimeZoneHours,
            siteLatitude: siteLatitude,
            siteLongitude: siteLongitude,
            siteLocationName: siteLocationName,
            naiveRaw: trimmed
        ),
           let instant = parseNaiveWallTime(
               trimmed,
               timeZoneOffsetSeconds: uddfTimeZoneHoursToOffsetSeconds(effectiveHours)
           ) {
            let offsetSeconds = uddfTimeZoneHoursToOffsetSeconds(effectiveHours)
            return Result(instant: instant, timeZoneOffsetSeconds: offsetSeconds)
        }

        if let instant = parseNaiveWallTime(trimmed, timeZoneOffsetSeconds: 0) {
            return Result(instant: instant, timeZoneOffsetSeconds: nil)
        }
        return nil
    }

    /// XML **`timezone`**, else offline inference from site coordinates / location (network re-parse runs in **`UddfImportedDiveNormalization`**).
    nonisolated static func resolvedSiteTimeZoneHours(
        xmlHours: Double?,
        siteLatitude: Double?,
        siteLongitude: Double?,
        siteLocationName: String? = nil,
        naiveRaw: String
    ) -> Double? {
        if let xmlHours { return xmlHours }
        let provisionalInstant = parseNaiveWallTime(naiveRaw, timeZoneOffsetSeconds: 0) ?? Date()
        if let siteLatitude, let siteLongitude,
           let hours = DiveSiteGeographyTimeZoneInference.uddfHoursFromUTC(
               latitude: siteLatitude,
               longitude: siteLongitude,
               at: provisionalInstant
           ) {
            return hours
        }
        return DiveSiteGeographyTimeZoneInference.uddfHoursFromLocationName(
            siteLocationName,
            at: provisionalInstant
        )
    }

    /// UDDF **`geography/timezone`** is a floating hours-from-UTC value.
    nonisolated static func uddfTimeZoneHoursToOffsetSeconds(_ hours: Double) -> Int {
        Int((hours * 3600).rounded())
    }

    // MARK: - ISO

    private nonisolated static func parseISOInstant(_ raw: String) -> Date? {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        if let d = isoFrac.date(from: raw) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let d = iso.date(from: raw) { return d }
        return nil
    }

    /// **`Z`**, or **`+07:00`** / **`+0700`** after the **`T`** time on **`datetime`**.
    private nonisolated static func explicitOffsetSeconds(in raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("Z") || trimmed.hasSuffix("z") { return 0 }

        guard let tIndex = trimmed.firstIndex(of: "T") else { return nil }
        let tail = trimmed[trimmed.index(after: tIndex)...]
        guard let signIndex = tail.firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        let offsetPart = String(tail[signIndex...])
        guard offsetPart.count >= 4, offsetPart.first == "+" || offsetPart.first == "-" else { return nil }
        let sign: Int = offsetPart.first == "-" ? -1 : 1
        let digits = offsetPart.dropFirst()

        let hours: Int
        let minutes: Int
        if digits.contains(":") {
            let parts = digits.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1]) else { return nil }
            hours = h
            minutes = m
        } else if digits.count == 4 {
            guard let h = Int(digits.prefix(2)), let m = Int(digits.suffix(2)) else { return nil }
            hours = h
            minutes = m
        } else if digits.count == 2 {
            guard let h = Int(digits) else { return nil }
            hours = h
            minutes = 0
        } else {
            return nil
        }
        return sign * (hours * 3600 + minutes * 60)
    }

    /// Naive **`datetime`** interpreted as UTC wall clock (legacy fallback).
    nonisolated static func parseNaiveWallTimeAsUtcInstant(_ raw: String) -> Date? {
        parseNaiveWallTime(raw, timeZoneOffsetSeconds: 0)
    }

    private nonisolated static func parseNaiveWallTime(_ raw: String, timeZoneOffsetSeconds: Int) -> Date? {
        let tz = TimeZone(secondsFromGMT: timeZoneOffsetSeconds) ?? .gmt
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        for format in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = format
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}
