import CoreMedia
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

enum DiveMediaFishialFrameExportError: Error, Equatable, Sendable {
    case missingLibraryIdentifier
    case assetUnavailable
    case imageEncodingFailed
    case videoDurationUnavailable
}

/// Exports JPEG stills from dive media for Fishial recognition.
enum DiveMediaFishialFrameExport {

    nonisolated static let maxJPEGEdge: CGFloat = 2_048
    nonisolated static let jpegCompressionQuality: CGFloat = 0.85
    nonisolated static let defaultVideoScrubFraction: Double = 0.5

    nonisolated static func cmTime(durationSeconds: Double, fraction: Double) -> CMTime {
        let clampedFraction = FishialVideoScrubPresentation.clampedFraction(fraction)
        let sampleSeconds = durationSeconds * clampedFraction
        return CMTime(seconds: sampleSeconds, preferredTimescale: 600)
    }

    nonisolated static func photoFilename(mediaID: UUID) -> String {
        "dive-media-\(mediaID.uuidString).jpg"
    }

    nonisolated static func scrubFrameFilename(mediaID: UUID, timeSeconds: Double) -> String {
        let millis = Int((timeSeconds * 1_000).rounded())
        return "dive-media-\(mediaID.uuidString)-t\(millis).jpg"
    }

    #if canImport(UIKit)
    /// Fast preview still for pinch/drag crop — does not wait for the full iCloud original.
    @MainActor
    static func makePhotoCropContext(for media: DiveMediaPhoto) async throws -> FishialStillCropContext {
        guard let localIdentifier = media.libraryAssetLocalIdentifier else {
            throw DiveMediaFishialFrameExportError.missingLibraryIdentifier
        }
        guard let previewImage = await loadPhotoPreviewImage(localIdentifier: localIdentifier) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }
        return FishialStillCropContext(
            diveMedia: media,
            previewImage: previewImage
        )
    }

    /// Exports a cropped full-quality JPEG for Fishial after the user frames the fish.
    @MainActor
    static func exportCroppedPhotoFrame(
        diveMedia: DiveMediaPhoto,
        cropViewportSize: CGSize,
        gestureScale: CGFloat,
        offset: CGSize,
        displayScale: CGFloat
    ) async throws -> FishialIdentifyCandidateFrame {
        guard let localIdentifier = diveMedia.libraryAssetLocalIdentifier else {
            throw DiveMediaFishialFrameExportError.missingLibraryIdentifier
        }
        guard let sourceImage = await loadPhotoExportImage(localIdentifier: localIdentifier) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }
        return try croppedCandidateFrame(
            sourceImage: sourceImage,
            cropViewportSize: cropViewportSize,
            gestureScale: gestureScale,
            offset: offset,
            filename: photoFilename(mediaID: diveMedia.id),
            displayScale: displayScale
        )
    }

    #if canImport(AVFoundation) && canImport(Photos)
    @MainActor
    static func makeVideoScrubContext(for media: DiveMediaPhoto) async throws -> FishialVideoScrubContext {
        guard let localIdentifier = media.libraryAssetLocalIdentifier else {
            throw DiveMediaFishialFrameExportError.missingLibraryIdentifier
        }
        guard let durationSeconds = DiveMediaReferenceLoader.videoDurationSeconds(
            localIdentifier: localIdentifier
        ) else {
            throw DiveMediaFishialFrameExportError.videoDurationUnavailable
        }
        guard let previewAsset = await DiveMediaReferenceLoader.loadVideoAsset(
            localIdentifier: localIdentifier,
            quality: FishialMediaSelectionPresentation.videoScrubRequestQuality
        ) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }

        return FishialVideoScrubContext(
            mediaID: media.id,
            localIdentifier: localIdentifier,
            durationSeconds: durationSeconds,
            previewAsset: previewAsset
        )
    }
    #endif

    @MainActor
    private static func loadPhotoPreviewImage(localIdentifier: String) async -> UIImage? {
        #if canImport(Photos)
        let edge = FishialMediaSelectionPresentation.photoPreviewMaxEdge
        return await DiveMediaReferenceLoader.image(
            localIdentifier: localIdentifier,
            targetSize: CGSize(width: edge, height: edge),
            contentMode: .aspectFit,
            deliveryMode: .fastFormat
        )
        #else
        return nil
        #endif
    }

    @MainActor
    private static func loadPhotoExportImage(localIdentifier: String) async -> UIImage? {
        #if canImport(Photos)
        let pixelSize = await fullPixelSize(localIdentifier: localIdentifier)
        let maxEdge = FishialMediaSelectionPresentation.photoExportMaxEdge
        let targetEdge = min(max(max(pixelSize.width, pixelSize.height), 1), maxEdge)
        return await DiveMediaReferenceLoader.image(
            localIdentifier: localIdentifier,
            targetSize: CGSize(width: targetEdge, height: targetEdge),
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat
        )
        #else
        return nil
        #endif
    }

    #if canImport(Photos)
    @MainActor
    private static func fullPixelSize(localIdentifier: String) async -> CGSize {
        guard let phAsset = DiveMediaReferenceLoader.asset(localIdentifier: localIdentifier) else {
            return CGSize(width: maxJPEGEdge, height: maxJPEGEdge)
        }
        return CGSize(width: phAsset.pixelWidth, height: phAsset.pixelHeight)
    }
    #endif

    #if canImport(AVFoundation)
    @MainActor
    static func cgImage(
        from generator: AVAssetImageGenerator,
        at time: CMTime
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: DiveMediaFishialFrameExportError.imageEncodingFailed)
                }
            }
        }
    }

    @MainActor
    static func makeImageGenerator(
        for avAsset: AVAsset,
        maxEdge: CGFloat
    ) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        return generator
    }

    /// Exact frame timing for Fishial video scrub preview (not keyframe-snapped).
    @MainActor
    static func makeScrubPreviewImageGenerator(for avAsset: AVAsset) -> AVAssetImageGenerator {
        let maxEdge = FishialMediaSelectionPresentation.videoScrubPreviewMaxEdge
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return generator
    }
    #endif

    @MainActor
    private static func jpegData(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: jpegCompressionQuality)
    }

    @MainActor
    static func croppedCandidateFrame(
        sourceImage: UIImage,
        cropViewportSize: CGSize,
        gestureScale: CGFloat,
        offset: CGSize,
        filename: String,
        displayScale: CGFloat
    ) throws -> FishialIdentifyCandidateFrame {
        guard let data = FishialImageCropRenderer.croppedJPEGData(
            from: sourceImage,
            cropSize: cropViewportSize,
            gestureScale: gestureScale,
            offset: offset,
            displayScale: displayScale,
            maxEdge: maxJPEGEdge,
            compressionQuality: jpegCompressionQuality
        ) else {
            throw DiveMediaFishialFrameExportError.imageEncodingFailed
        }
        guard let previewImage = UIImage(data: data) else {
            throw DiveMediaFishialFrameExportError.imageEncodingFailed
        }
        return FishialIdentifyCandidateFrame(
            data: data,
            filename: filename,
            previewImage: previewImage
        )
    }
    #endif
}

#if canImport(UIKit) && canImport(AVFoundation)
/// Scrubbable video source for picking one still before Fishial recognition.
@MainActor
final class FishialVideoScrubContext {
    let mediaID: UUID
    let localIdentifier: String
    let durationSeconds: Double
    /// Lighter PhotoKit stream for immediate scrub preview.
    let previewAsset: AVAsset

    /// Alias for the scrub player — preview quality only.
    var avAsset: AVAsset { previewAsset }

    init(
        mediaID: UUID,
        localIdentifier: String,
        durationSeconds: Double,
        previewAsset: AVAsset
    ) {
        self.mediaID = mediaID
        self.localIdentifier = localIdentifier
        self.durationSeconds = durationSeconds
        self.previewAsset = previewAsset
    }

    func exportCandidateFrame(atFraction fraction: Double) async throws -> FishialIdentifyCandidateFrame {
        guard let exportAsset = await DiveMediaReferenceLoader.loadVideoAsset(
            localIdentifier: localIdentifier,
            quality: FishialMediaSelectionPresentation.videoExportRequestQuality
        ) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }
        let exportGenerator = DiveMediaFishialFrameExport.makeImageGenerator(
            for: exportAsset,
            maxEdge: DiveMediaFishialFrameExport.maxJPEGEdge
        )
        let clampedFraction = FishialVideoScrubPresentation.clampedFraction(fraction)
        let time = DiveMediaFishialFrameExport.cmTime(
            durationSeconds: durationSeconds,
            fraction: clampedFraction
        )
        let cgImage = try await DiveMediaFishialFrameExport.cgImage(from: exportGenerator, at: time)
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: DiveMediaFishialFrameExport.jpegCompressionQuality) else {
            throw DiveMediaFishialFrameExportError.imageEncodingFailed
        }
        let timeSeconds = durationSeconds * clampedFraction
        return FishialIdentifyCandidateFrame(
            data: data,
            filename: DiveMediaFishialFrameExport.scrubFrameFilename(
                mediaID: mediaID,
                timeSeconds: timeSeconds
            ),
            previewImage: image
        )
    }
}
#endif
