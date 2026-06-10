import CoreGraphics
import Foundation

/// Video fidelity ladder for dive overview heroes (poster → preview stream → full stream).
enum DiveMediaVideoFidelity: Int, Sendable, Comparable {
    case none = 0
    case preview = 1
    case full = 2

    nonisolated static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Progressive load policy for dive **Media** tab heroes (testable without PhotoKit / AVFoundation).
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

    nonisolated static func shouldUpgradeToFullVideo(
        isPlaybackActive: Bool,
        isPausedByUserHold: Bool,
        currentFidelity: DiveMediaVideoFidelity,
        isNetworkAvailable: Bool = true
    ) -> Bool {
        isNetworkAvailable
            && isPlaybackActive
            && !isPausedByUserHold
            && currentFidelity == .preview
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
