import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Video fidelity ladder for dive overview heroes (poster → preview stream → full stream).
enum DiveMediaVideoFidelity: Int, Sendable, Comparable {
    case none = 0
    case preview = 1
    case full = 2

    nonisolated static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Progressive load policy for dive media heroes (testable without PhotoKit / AVFoundation).
enum DiveMediaProgressivePresentation: Sendable {

    /// Fast poster edge before preview / full video streams resolve.
    nonisolated static let posterImageEdge: CGFloat = 480

    nonisolated static func posterTargetSize(screenPixelWidth: CGFloat) -> CGSize {
        let edge = min(
            posterImageEdge,
            DiveActivityMediaPresentation.fullScreenImageTargetEdge(screenPixelWidth: screenPixelWidth)
        )
        return CGSize(width: edge, height: edge)
    }

    /// Fallback when no pixel metric is available (tests / non-UIKit).
    nonisolated static func preferredStillImage<Image>(
        progressive: Image?,
        sessionCached: Image?,
        storedPreview: Image?
    ) -> Image? {
        progressive ?? sessionCached ?? storedPreview
    }

    #if canImport(UIKit)
    /// Prefer the sharpest candidate by pixel area so soft 256px JPEGs never mask a warmer hero.
    nonisolated static func preferredStillImage(
        progressive: UIImage?,
        sessionCached: UIImage?,
        storedPreview: UIImage?
    ) -> UIImage? {
        [progressive, sessionCached, storedPreview]
            .compactMap { $0 }
            .max { lhs, rhs in pixelArea(lhs) < pixelArea(rhs) }
    }

    nonisolated static func pixelArea(_ image: UIImage) -> CGFloat {
        image.size.width * image.size.height * image.scale * image.scale
    }
    #endif

    /// Progressive paths may upgrade preview → full once the preview stream is on screen.
    nonisolated static func allowsFullQualityUpgrade(
        for libraryVideoQuality: DiveMediaVideoRequestQuality
    ) -> Bool {
        _ = libraryVideoQuality
        return true
    }

    /// Never race a full-quality iCloud download against the initial preview resolve.
    nonisolated static func allowsBackgroundFullVideoUpgrade(
        for libraryVideoQuality: DiveMediaVideoRequestQuality
    ) -> Bool {
        _ = libraryVideoQuality
        return false
    }

    /// Full upgrade only after preview playback is actually displaying (not merely resolved).
    nonisolated static func shouldScheduleFullVideoUpgrade(
        isPlaybackActive: Bool,
        isPausedByUserHold: Bool,
        currentFidelity: DiveMediaVideoFidelity,
        isPreviewDisplayReady: Bool,
        isNetworkAvailable: Bool = true
    ) -> Bool {
        shouldUpgradeToFullVideo(
            isPlaybackActive: isPlaybackActive,
            isPausedByUserHold: isPausedByUserHold,
            currentFidelity: currentFidelity,
            isNetworkAvailable: isNetworkAvailable,
            allowsBackgroundUpgrade: false
        ) && isPreviewDisplayReady
    }

    /// Brief settle after preview is on screen before requesting **`.highQualityFormat`**.
    nonisolated static let fullQualityUpgradeDelayNanoseconds: UInt64 = 400_000_000

    nonisolated static func shouldUpgradeToFullVideo(
        isPlaybackActive: Bool,
        isPausedByUserHold: Bool,
        currentFidelity: DiveMediaVideoFidelity,
        isNetworkAvailable: Bool = true,
        allowsBackgroundUpgrade: Bool = false
    ) -> Bool {
        isNetworkAvailable
            && !isPausedByUserHold
            && currentFidelity == .preview
            && (isPlaybackActive || allowsBackgroundUpgrade)
    }

    nonisolated static func resolvedKey(
        sourceIdentityKey: String,
        fidelity: DiveMediaVideoFidelity
    ) -> String {
        switch fidelity {
        case .none:
            return sourceIdentityKey
        case .preview:
            return "\(sourceIdentityKey)|preview"
        case .full:
            return "\(sourceIdentityKey)|full"
        }
    }

    /// Preview → full stream swap for the same library asset (not a new clip).
    nonisolated static func isVideoQualityFidelityUpgrade(
        from previousResolvedKey: String?,
        to nextResolvedKey: String
    ) -> Bool {
        previousResolvedKey?.hasSuffix("|preview") == true && nextResolvedKey.hasSuffix("|full")
    }

    nonisolated static func previewResolvedKey(forFullResolvedKey fullKey: String) -> String? {
        guard fullKey.hasSuffix("|full") else { return nil }
        return String(fullKey.dropLast("|full".count)) + "|preview"
    }

    /// Stable SwiftUI identity — must not change when fidelity suffix moves from **`|preview`** to **`|full`**.
    nonisolated static func playerRepresentableIdentity(
        sourceIdentityKey: String,
        playbackActivationGeneration: Int
    ) -> String {
        "\(sourceIdentityKey)-activate-\(playbackActivationGeneration)"
    }

    nonisolated static func shouldPrefetchAdjacentMedia(isMediaTabSelected: Bool) -> Bool {
        isMediaTabSelected
    }

    /// Indices to warm when **`selectedIndex`** is visible (current + neighbors).
    nonisolated static func prefetchNeighborIndices(
        selectedIndex: Int,
        itemCount: Int
    ) -> [Int] {
        guard itemCount > 0 else { return [] }
        let clamped = min(max(selectedIndex, 0), itemCount - 1)
        var indices = [clamped]
        if clamped > 0 { indices.append(clamped - 1) }
        if clamped + 1 < itemCount { indices.append(clamped + 1) }
        return indices
    }
}
