import CoreGraphics
import Foundation

/// Full-screen linked-media gestures — horizontal browse, vertical dismiss (Photos-style).
enum LinkedMediaFullscreenPresentation: Sendable {

    enum DragAxis: Sendable, Equatable {
        case horizontal
        case vertical
    }

    nonisolated static let swipeMinimumDistance: CGFloat = 12
    nonisolated static let horizontalAdvanceThreshold: CGFloat = 36
    nonisolated static let dismissThreshold: CGFloat = 120
    nonisolated static let dismissMinScale: CGFloat = 0.82
    nonisolated static let dismissBackgroundFade: Double = 0.65
    nonisolated static let browseAnimationDuration: TimeInterval = 0.32
    nonisolated static let browseAnimationDamping: CGFloat = 0.84
    /// Swipe-to-dismiss completion window — keep in sync with **`gestureDismissSpringResponse`**.
    nonisolated static let gestureDismissAnimationDuration: TimeInterval = 0.22
    nonisolated static let gestureDismissSpringResponse: TimeInterval = 0.26
    nonisolated static let gestureDismissSpringDamping: CGFloat = 0.9

    /// Deprecated alias — use **`gestureDismissAnimationDuration`**.
    nonisolated static let dismissAnimationDuration: TimeInterval = gestureDismissAnimationDuration

    /// Portrait fullscreen — extra offset below the status bar / Dynamic Island for the top chrome row.
    nonisolated static let portraitTopChromeExtraInset: CGFloat = 40
    /// Matches **`AppTheme.Spacing.md`** — shared gap below **`topChromeInset`** for X / chips / **View on dive**.
    nonisolated static let topChromeRowPadding: CGFloat = 16

    nonisolated static func topChromeInset(safeAreaTop: CGFloat, containerSize: CGSize) -> CGFloat {
        let isPortrait = containerSize.height >= containerSize.width
        return safeAreaTop + (isPortrait ? portraitTopChromeExtraInset : 0)
    }

    /// Distance from the top of the container to the top chrome row (portrait bump included).
    nonisolated static func topChromeRowOffset(safeAreaTop: CGFloat, containerSize: CGSize) -> CGFloat {
        topChromeInset(safeAreaTop: safeAreaTop, containerSize: containerSize) + topChromeRowPadding
    }

    nonisolated static func lockedDragAxis(
        translation: CGSize,
        minimumDistance: CGFloat = swipeMinimumDistance
    ) -> DragAxis? {
        let width = abs(translation.width)
        let height = abs(translation.height)
        guard max(width, height) >= minimumDistance else { return nil }
        return width > height ? .horizontal : .vertical
    }

    /// **`+1`** = next item (swipe left), **`-1`** = previous (swipe right).
    nonisolated static func browseOffset(forHorizontalTranslation translation: CGFloat) -> Int? {
        guard abs(translation) >= horizontalAdvanceThreshold else { return nil }
        if translation < 0 { return 1 }
        if translation > 0 { return -1 }
        return nil
    }

    nonisolated static func interactiveBrowseProgress(
        horizontalTranslation: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        guard containerWidth > 0 else { return 0 }
        return min(abs(horizontalTranslation) / containerWidth, 1)
    }

    nonisolated static func interactiveBrowseStep(forHorizontalTranslation translation: CGFloat) -> Int? {
        if translation < 0 { return 1 }
        if translation > 0 { return -1 }
        return nil
    }

    nonisolated static func rubberBandedBrowseTranslation(
        _ translation: CGFloat,
        canBrowseForward: Bool,
        canBrowseBackward: Bool,
        resistance: CGFloat = TripDetailMediaGalleryPresentation.browseEdgeResistance
    ) -> CGFloat {
        if translation < 0, !canBrowseForward { return translation * resistance }
        if translation > 0, !canBrowseBackward { return translation * resistance }
        return translation
    }

    nonisolated static func adjacentItemOffsetX(
        horizontalTranslation: CGFloat,
        containerWidth: CGFloat
    ) -> CGFloat {
        if horizontalTranslation < 0 {
            return containerWidth + horizontalTranslation
        }
        if horizontalTranslation > 0 {
            return -containerWidth + horizontalTranslation
        }
        return 0
    }

    nonisolated static func interactiveCommitTranslation(step: Int, containerWidth: CGFloat) -> CGFloat {
        step > 0 ? -containerWidth : containerWidth
    }

    nonisolated static func interactiveCurrentScale(progress: CGFloat) -> CGFloat {
        TripDetailMediaGalleryPresentation.interactiveCurrentScale(progress: progress)
    }

    nonisolated static func interactiveAdjacentScale(progress: CGFloat) -> CGFloat {
        TripDetailMediaGalleryPresentation.interactiveAdjacentScale(progress: progress)
    }

    nonisolated static func interactiveCurrentOpacity(progress: CGFloat) -> Double {
        TripDetailMediaGalleryPresentation.interactiveCurrentOpacity(progress: progress)
    }

    nonisolated static func interactiveAdjacentOpacity(progress: CGFloat) -> Double {
        TripDetailMediaGalleryPresentation.interactiveAdjacentOpacity(progress: progress)
    }

    nonisolated static func dismissProgress(
        verticalTranslation: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        let normalizedThreshold = max(containerHeight * 0.45, dismissThreshold)
        guard normalizedThreshold > 0 else { return 0 }
        return min(abs(verticalTranslation) / normalizedThreshold, 1)
    }

    nonisolated static func dismissScale(progress: CGFloat) -> CGFloat {
        1 - (1 - dismissMinScale) * progress
    }

    nonisolated static func dismissBackgroundOpacity(progress: CGFloat) -> Double {
        1 - dismissBackgroundFade * Double(progress)
    }

    nonisolated static func shouldDismiss(
        verticalTranslation: CGFloat,
        predictedEndTranslation: CGFloat,
        containerHeight: CGFloat
    ) -> Bool {
        let progress = dismissProgress(
            verticalTranslation: verticalTranslation,
            containerHeight: containerHeight
        )
        if progress >= 0.35 { return true }
        return abs(predictedEndTranslation) > containerHeight * 0.25
    }

    nonisolated static func browseAccessibilityHint(itemCount: Int) -> String {
        guard itemCount > 1 else {
            return "Swipe up or down to close."
        }
        return "Swipe left or right for next or previous. Swipe up or down to close."
    }

    nonisolated static func linkedDiveCoverIdentity(diveID: UUID, mediaID: UUID) -> String {
        "\(diveID.uuidString)-\(mediaID.uuidString)"
    }
}

typealias DiveBuddyTaggedMediaFullscreenPresentation = LinkedMediaFullscreenPresentation
