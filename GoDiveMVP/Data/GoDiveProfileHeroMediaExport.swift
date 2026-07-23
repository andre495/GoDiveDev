import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif

/// Builds upload bytes from the owner's profile hero **`DiveMediaPhoto`** (PhotoKit).
enum GoDiveProfileHeroMediaExport: Sendable {
    nonisolated static let maxVideoExportSeconds: Double = 45
    nonisolated static let maxJPEGBytes = 2_500_000

    enum Payload: Equatable, Sendable {
        case image(Data)
        case video(Data)
    }

    @MainActor
    static func exportPayload(for media: DiveMediaPhoto) async -> Payload? {
        let kind = DiveMediaKind(rawValue: media.mediaKind) ?? .image
        switch kind {
        case .image:
            guard let jpeg = await exportJPEG(for: media) else { return nil }
            return .image(jpeg)
        case .video:
            guard let mp4 = await exportProfileVideoMP4(for: media) else { return nil }
            return .video(mp4)
        }
    }

    @MainActor
    private static func exportJPEG(for media: DiveMediaPhoto) async -> Data? {
        if let preview = media.previewJPEGData, !preview.isEmpty, preview.count <= maxJPEGBytes {
            return preview
        }
        let localID = media.photosLocalIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localID.isEmpty else {
            return cappedJPEG(from: media.previewJPEGData)
        }
        let edge: CGFloat = 1920
        let image = await DiveMediaReferenceLoader.image(
            localIdentifier: localID,
            targetSize: CGSize(width: edge, height: edge),
            contentMode: .aspectFill,
            deliveryMode: .highQualityFormat
        )
        #if canImport(UIKit)
        guard let image, let data = image.jpegData(compressionQuality: 0.82) else {
            return cappedJPEG(from: media.previewJPEGData)
        }
        return data.count <= maxJPEGBytes ? data : image.jpegData(compressionQuality: 0.72)
        #else
        return cappedJPEG(from: media.previewJPEGData)
        #endif
    }

    @MainActor
    private static func exportProfileVideoMP4(for media: DiveMediaPhoto) async -> Data? {
        let localID = media.photosLocalIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localID.isEmpty else { return nil }

        guard let asset = await DiveMediaReferenceLoader.loadVideoAsset(
            localIdentifier: localID,
            quality: .fullQuality
        ) else { return nil }

        return await Task.detached(priority: .utility) {
            await Self.transcodeToMP4(asset: asset, maxDuration: maxVideoExportSeconds)
        }.value
    }

    #if canImport(AVFoundation)
    nonisolated private static func transcodeToMP4(asset: AVAsset, maxDuration: Double) async -> Data? {
        let composition = AVMutableComposition()
        guard let sourceVideo = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        let duration = (try? await asset.load(.duration)) ?? .zero
        let cappedSeconds = min(duration.seconds, maxDuration)
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
            .appendingPathComponent("godive-profile-hero-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1280x720
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
        return try? Data(contentsOf: outputURL)
    }
    #endif

    nonisolated private static func cappedJPEG(from data: Data?) -> Data? {
        guard let data, !data.isEmpty, data.count <= maxJPEGBytes else { return nil }
        return data
    }
}
