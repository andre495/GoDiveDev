import CoreGraphics
import Foundation

/// Layout + copy for the animated upload prompt on the dive **Media** hero when a dive has no photos yet.
enum DiveActivityMediaEmptyHeroPresentation: Sendable {

    static let title = HomeMediaCarouselEmptyPresentation.title
    static let message =
        "Add photos or videos, or turn on auto-upload in Settings to pull in matching library media."
    static let uploadMediaCTATitle = "Upload Media"
    /// Padding under the **Upload Media** CTA so it clears the overview sheet seam.
    nonisolated static let uploadMediaCTABottomInset: CGFloat = 16
    /// Matches compact Liquid Glass capsule height (**`AppTheme.Layout.glassChromeControlHeight`**).
    nonisolated static let uploadMediaCTAHeight: CGFloat = 44
    /// Nudge ghost frames down toward the **Upload Media** CTA (button position stays fixed).
    nonisolated static let ghostFramesDownshift: CGFloat = 40

    /// Liquid Glass **Upload Media** CTA in the hero band above the sheet (**minimized** / **medium**).
    nonisolated static func showsUploadMediaCTA(forHeightFraction fraction: CGFloat) -> Bool {
        showsHeroGhostFrames(forHeightFraction: fraction)
    }

    /// Vertical center of the ghost-frame animation in the band above the overview sheet.
    /// When the **Upload Media** CTA is shown, the animation sits in the space *above* the CTA,
    /// then shifts down by **`ghostFramesDownshift`** (CTA Y is unchanged).
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
        guard showsUploadMediaCTA(forHeightFraction: sheetHeightFraction) else {
            return band.top + band.height / 2 + ghostFramesDownshift
        }
        let animationBandHeight = max(
            0,
            band.height - uploadMediaCTAReservedHeight(forHeightFraction: sheetHeightFraction)
        )
        let centeredY = band.top + animationBandHeight / 2
        let ctaTop = uploadMediaCTACenterY(
            layoutHeight: layoutHeight,
            sheetHeightFraction: sheetHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstructionHeight
        ) - uploadMediaCTAHeight / 2
        // Keep a small gap above the button so frames don’t sit on the CTA.
        let maxCenterY = max(centeredY, ctaTop - 12)
        return min(centeredY + ghostFramesDownshift, maxCenterY)
    }

    /// Y position for the **Upload Media** CTA center — pinned near the bottom of the visible hero band,
    /// directly under the ghost-frame animation and above the overview sheet.
    nonisolated static func uploadMediaCTACenterY(
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
        return band.top + band.height - uploadMediaCTABottomInset - uploadMediaCTAHeight / 2
    }

    /// Height reserved under the ghost frames for CTA + spacing above the sheet seam.
    nonisolated static func uploadMediaCTAReservedHeight(forHeightFraction fraction: CGFloat) -> CGFloat {
        guard showsUploadMediaCTA(forHeightFraction: fraction) else { return 0 }
        return uploadMediaCTAHeight + uploadMediaCTABottomInset + 12
    }

    /// Ghost-frame animation in the hero — hidden at **large** when the sheet covers most of the screen.
    nonisolated static func showsHeroGhostFrames(forHeightFraction fraction: CGFloat) -> Bool {
        DiveActivityOverviewDetent.nearest(toHeightFraction: fraction) != .large
    }

    /// The empty overview sheet reuses the populated Media layout (identity header, tag sections,
    /// carousel row) — upload copy lives only in the hero band with the **Upload Media** CTA.
    nonisolated static func showsUploadPromptTextInSheet(for detent: DiveActivityOverviewDetent) -> Bool {
        _ = detent
        return false
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
        }
    }

    /// Slightly smaller at **medium** so the prompt fits the band above the half-height sheet.
    nonisolated static func promptScale(forHeightFraction fraction: CGFloat) -> CGFloat {
        let detent = DiveActivityOverviewDetent.nearest(toHeightFraction: fraction)
        switch detent {
        case .minimized, .large:
            return 1
        }
    }

    /// Deprecated — copy moved to the overview sheet.
    nonisolated static func promptVerticalOffset(forHeightFraction fraction: CGFloat) -> CGFloat {
        ghostFramesVerticalOffset(forHeightFraction: fraction)
    }
}
