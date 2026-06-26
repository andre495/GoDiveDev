import CoreGraphics
import Foundation

/// Layout + copy for the animated upload prompt on the dive **Media** hero when a dive has no photos yet.
enum DiveActivityMediaEmptyHeroPresentation: Sendable {

    static let title = HomeMediaCarouselEmptyPresentation.title
    static let message =
        "Tap + below to add photos or videos — or turn on auto-upload in Settings to pull in matching library media."

    /// Vertical center of ghost frames in the hero band above the overview sheet.
    nonisolated static func ghostFramesCenterY(
        layoutHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        bottomSafeInset: CGFloat,
        topObstructionHeight: CGFloat
    ) -> CGFloat {
        let band = visibleHeroBand(
            layoutHeight: layoutHeight,
            sheetHeightFraction: sheetHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstructionHeight
        )
        return band.top + band.height / 2
    }

    /// Ghost-frame animation in the hero — hidden at **large** when the sheet covers most of the screen.
    nonisolated static func showsHeroGhostFrames(forHeightFraction fraction: CGFloat) -> Bool {
        DiveActivityOverviewDetent.nearest(toHeightFraction: fraction) != .large
    }

    /// Upload copy lives in the overview sheet at **medium** and **large** (not **minimized**).
    nonisolated static func showsUploadPromptTextInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .medium || detent == .large
    }

    /// Back-compat alias for layout tests.
    nonisolated static func promptCenterY(
        layoutHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        bottomSafeInset: CGFloat,
        topObstructionHeight: CGFloat
    ) -> CGFloat {
        ghostFramesCenterY(
            layoutHeight: layoutHeight,
            sheetHeightFraction: sheetHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstructionHeight
        )
    }

    nonisolated static func visibleHeroBand(
        layoutHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        bottomSafeInset: CGFloat,
        topObstructionHeight: CGFloat
    ) -> (top: CGFloat, height: CGFloat) {
        guard layoutHeight > 0 else { return (0, 0) }
        let sheetHeight = DiveActivityOverviewDetent.sheetHeight(
            forHeightFraction: sheetHeightFraction,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset
        )
        let sheetTop = layoutHeight - sheetHeight
        let top = max(0, topObstructionHeight)
        let height = max(0, sheetTop - top)
        return (top, height)
    }

    /// Slightly smaller at **medium** so frames fit the band above the half-height sheet.
    nonisolated static func ghostFramesScale(forHeightFraction fraction: CGFloat) -> CGFloat {
        promptScale(forHeightFraction: fraction)
    }

    nonisolated static func ghostFramesVerticalOffset(forHeightFraction fraction: CGFloat) -> CGFloat {
        let detent = DiveActivityOverviewDetent.nearest(toHeightFraction: fraction)
        switch detent {
        case .minimized, .large:
            return 0
        case .medium:
            return -16
        }
    }

    /// Slightly smaller at **medium** so the prompt fits the band above the half-height sheet.
    nonisolated static func promptScale(forHeightFraction fraction: CGFloat) -> CGFloat {
        let detent = DiveActivityOverviewDetent.nearest(toHeightFraction: fraction)
        switch detent {
        case .minimized, .large:
            return 1
        case .medium:
            return 0.9
        }
    }

    /// Deprecated — copy moved to the overview sheet.
    nonisolated static func promptVerticalOffset(forHeightFraction fraction: CGFloat) -> CGFloat {
        ghostFramesVerticalOffset(forHeightFraction: fraction)
    }
}
