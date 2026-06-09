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
    @MainActor
    static func exportPhotoCandidate(for media: DiveMediaPhoto) async throws -> FishialIdentifyCandidateFrame {
        guard let localIdentifier = media.libraryAssetLocalIdentifier else {
            throw DiveMediaFishialFrameExportError.missingLibraryIdentifier
        }
        guard let data = try await exportPhotoJPEG(localIdentifier: localIdentifier) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }
        guard let previewImage = UIImage(data: data) else {
            throw DiveMediaFishialFrameExportError.imageEncodingFailed
        }
        return FishialIdentifyCandidateFrame(
            data: data,
            filename: photoFilename(mediaID: media.id),
            previewImage: previewImage
        )
    }

    #if canImport(AVFoundation) && canImport(Photos)
    @MainActor
    static func makeVideoScrubContext(for media: DiveMediaPhoto) async throws -> FishialVideoScrubContext {
        guard let localIdentifier = media.libraryAssetLocalIdentifier else {
            throw DiveMediaFishialFrameExportError.missingLibraryIdentifier
        }
        guard let avAsset = await DiveMediaReferenceLoader.loadVideoAsset(localIdentifier: localIdentifier) else {
            throw DiveMediaFishialFrameExportError.assetUnavailable
        }

        let duration = try await avAsset.load(.duration)
        let durationSeconds = duration.seconds
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw DiveMediaFishialFrameExportError.videoDurationUnavailable
        }

        return FishialVideoScrubContext(
            mediaID: media.id,
            durationSeconds: durationSeconds,
            avAsset: avAsset
        )
    }
    #endif

    @MainActor
    private static func exportPhotoJPEG(localIdentifier: String) async throws -> Data? {
        #if canImport(Photos)
        let pixelSize = await fullPixelSize(localIdentifier: localIdentifier)
        let targetEdge = min(max(max(pixelSize.width, pixelSize.height), 1), maxJPEGEdge)
        let targetSize = CGSize(width: targetEdge, height: targetEdge)
        guard let image = await DiveMediaReferenceLoader.image(
            localIdentifier: localIdentifier,
            targetSize: targetSize,
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat
        ) else {
            return nil
        }
        return jpegData(from: image)
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
    #endif

    @MainActor
    private static func jpegData(from image: UIImage) -> Data? {
        image.jpegData(compressionQuality: jpegCompressionQuality)
    }
    #endif
}

#if canImport(UIKit) && canImport(AVFoundation)
/// Scrubbable video source for picking one still before Fishial recognition.
@MainActor
final class FishialVideoScrubContext {
    let mediaID: UUID
    let durationSeconds: Double
    let avAsset: AVAsset

    private let exportGenerator: AVAssetImageGenerator

    init(mediaID: UUID, durationSeconds: Double, avAsset: AVAsset) {
        self.mediaID = mediaID
        self.durationSeconds = durationSeconds
        self.avAsset = avAsset
        exportGenerator = DiveMediaFishialFrameExport.makeImageGenerator(
            for: avAsset,
            maxEdge: DiveMediaFishialFrameExport.maxJPEGEdge
        )
    }

    func exportCandidateFrame(atFraction fraction: Double) async throws -> FishialIdentifyCandidateFrame {
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
