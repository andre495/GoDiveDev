import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(ImageIO)
import ImageIO
#endif

/// Builds tiered upload bytes for friend-visible shared activity media (dives + snorkels).
///
/// Phase one of a publish only needs **`exportThumbnailJPEG`** (stored 256 px preview bytes when
/// available — no PhotoKit). The expensive content tiers (**4096 px JPEG**, **1080p MP4**) are
/// exported lazily by the background upload queue via the `photosLocalIdentifier` variants.
enum GoDiveSharedMediaExport: Sendable {

    @MainActor
    static func exportThumbnailJPEG<T: ActivityOverviewGalleryMedia>(for media: T) async -> Data? {
        if let preview = media.previewJPEGData, !preview.isEmpty {
            if preview.count <= GoDiveSharedMediaLimits.thumbMaxBytes {
                return preview
            }
            #if canImport(UIKit)
            if let image = UIImage(data: preview) {
                return DiveMediaPreviewPersistence.encodePreviewJPEG(image)
            }
            #endif
        }
        guard let localID = media.libraryAssetLocalIdentifier else { return nil }
        let edge = DiveMediaPreviewPersistence.storedPreviewEdge
        guard let image = await DiveMediaReferenceLoader.image(
            localIdentifier: localID,
            targetSize: CGSize(width: edge, height: edge),
            contentMode: .aspectFill,
            deliveryMode: .highQualityFormat
        ) else { return nil }
        #if canImport(UIKit)
        return DiveMediaPreviewPersistence.encodePreviewJPEG(image)
        #else
        return nil
        #endif
    }

    /// Full-quality share JPEG for the content tier (background queue).
    @MainActor
    static func exportPhotoContentJPEG(photosLocalIdentifier: String) async -> Data? {
        let localID = photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localID.isEmpty else { return nil }
        let edge = CGFloat(GoDiveSharedMediaLimits.photoContentMaxPixelEdge)
        guard let image = await DiveMediaReferenceLoader.image(
            localIdentifier: localID,
            targetSize: CGSize(width: edge, height: edge),
            contentMode: .aspectFill,
            deliveryMode: .highQualityFormat
        ) else { return nil }
        #if canImport(UIKit)
        return sharePhotoJPEG(from: image)
        #else
        return nil
        #endif
    }

    /// 1080p / 30 s MP4 for the content tier (background queue).
    @MainActor
    static func exportSharedVideoMP4(photosLocalIdentifier: String) async -> Data? {
        let localID = photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localID.isEmpty else { return nil }
        guard let asset = await DiveMediaReferenceLoader.loadVideoAsset(
            localIdentifier: localID,
            quality: .fullQuality
        ) else { return nil }

        return await Task.detached(priority: .utility) {
            await transcodeToSharedMP4(asset: asset)
        }.value
    }

    #if canImport(UIKit)
    nonisolated static func sharePhotoJPEG(from image: UIImage) -> Data? {
        let normalized = normalizedSharePhotoImage(from: image)
        let qualities: [CGFloat] = [0.85, 0.75]
        for quality in qualities {
            guard let data = normalized.jpegData(compressionQuality: quality),
                  data.count <= GoDiveSharedMediaLimits.photoContentMaxBytes
            else { continue }
            return data
        }
        return nil
    }

    /// Re-encodes through a bitmap context so location / EXIF metadata is not copied into shared JPEGs.
    nonisolated static func normalizedSharePhotoImage(from image: UIImage) -> UIImage {
        let scaled = DiveMediaPreviewPersistence.scaledImage(
            image,
            maxPixelEdge: CGFloat(GoDiveSharedMediaLimits.photoContentMaxPixelEdge)
        )
        let pixelWidth = max(scaled.size.width * scaled.scale, 1)
        let pixelHeight = max(scaled.size.height * scaled.scale, 1)
        let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            scaled.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated static func jpegDimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard let image = UIImage(data: data) else { return nil }
        let width = Int((image.size.width * image.scale).rounded())
        let height = Int((image.size.height * image.scale).rounded())
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }

    #if canImport(ImageIO)
    nonisolated static func jpegContainsGPSMetadata(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return false }
        return properties[kCGImagePropertyGPSDictionary] != nil
    }
    #endif
    #endif

    nonisolated static func cappedVideoExportDurationSeconds(_ sourceSeconds: Double) -> Double {
        guard sourceSeconds.isFinite, sourceSeconds > 0 else { return 0 }
        return min(sourceSeconds, GoDiveSharedMediaLimits.maxSharedVideoDurationSeconds)
    }

    #if canImport(AVFoundation)
    nonisolated private static func transcodeToSharedMP4(asset: AVAsset) async -> Data? {
        let composition = AVMutableComposition()
        guard let sourceVideo = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let duration = (try? await asset.load(.duration)) ?? .zero
        let cappedSeconds = cappedVideoExportDurationSeconds(duration.seconds)
        guard cappedSeconds > 0.25 else { return nil }
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: cappedSeconds, preferredTimescale: 600)
        )

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return nil }
        try? videoTrack.insertTimeRange(timeRange, of: sourceVideo, at: .zero)

        if let sourceAudio = try? await asset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? audioTrack.insertTimeRange(timeRange, of: sourceAudio, at: .zero)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("godive-shared-media-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1920x1080
        ) else { return nil }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        if #available(iOS 18.0, *) {
            do {
                try await export.export(to: outputURL, as: .mp4)
            } catch {
                return nil
            }
        } else {
            await export.export()
            guard export.status == .completed else { return nil }
        }

        guard let data = try? Data(contentsOf: outputURL),
              data.count <= GoDiveSharedMediaLimits.videoStorageMaxBytes
        else { return nil }
        return data
    }
    #endif
}
