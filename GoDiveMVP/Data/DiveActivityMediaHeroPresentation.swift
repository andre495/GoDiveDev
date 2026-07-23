import CoreGraphics
import Foundation

/// **Media** tab hero sizing — aspect-fill in the band from screen top to sheet seam at **large**, full viewport fill at **minimized**.
enum DiveActivityMediaHeroPresentation: Sendable {

    /// Bleed below the flat sheet seam so media tucks under the embedded panel’s rounded top corners (**`AppTheme.Sheet.cornerRadius`**).
    nonisolated static let sheetSeamCornerBleed: CGFloat = 20

    /// **0** at resting **large** (fill hero band edge-to-edge); **1** at resting **minimized** (full-screen fill).
    nonisolated static func fullBleedProgress(
        sheetHeightFraction: CGFloat,
        layoutContext: DiveActivityOverviewSheetLayoutContext
    ) -> CGFloat {
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let range = large - minimized
        guard range > 0.0001 else { return 1 }
        return min(max((large - sheetHeightFraction) / range, 0), 1)
    }

    nonisolated static func heroBandRect(
        viewportSize: CGSize,
        layoutHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        bottomSafeInset: CGFloat,
        topObstructionHeight: CGFloat
    ) -> CGRect {
        let resolvedLayoutHeight = layoutHeight > 0 ? layoutHeight : viewportSize.height
        let sheetHeight = DiveActivityOverviewDetent.sheetHeight(
            forHeightFraction: sheetHeightFraction,
            layoutHeight: resolvedLayoutHeight,
            bottomSafeInset: bottomSafeInset
        )
        let sheetTop = resolvedLayoutHeight - sheetHeight
        _ = topObstructionHeight
        let bandTop: CGFloat = 0
        let bandHeight = max(0, sheetTop - bandTop + sheetSeamCornerBleed)
        return CGRect(x: 0, y: bandTop, width: viewportSize.width, height: bandHeight)
    }

    /// Bottom of the flat sheet seam (before corner bleed) in layout coordinates.
    nonisolated static func sheetSeamY(
        layoutHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        bottomSafeInset: CGFloat
    ) -> CGFloat {
        let resolvedLayoutHeight = max(layoutHeight, 1)
        let sheetHeight = DiveActivityOverviewDetent.sheetHeight(
            forHeightFraction: sheetHeightFraction,
            layoutHeight: resolvedLayoutHeight,
            bottomSafeInset: bottomSafeInset
        )
        return resolvedLayoutHeight - sheetHeight
    }

    nonisolated static func interpolatedMediaCenterY(
        band: CGRect,
        viewportHeight: CGFloat,
        mediaAspect: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let bandFill = aspectFillSize(mediaAspect: mediaAspect, in: band.size)
        let bandAlignedY = band.maxY - bandFill.height / 2
        let fullBleedY = viewportHeight / 2
        return bandAlignedY + (fullBleedY - bandAlignedY) * clamped
    }

    nonisolated static func interpolatedMediaSize(
        mediaAspect: CGFloat,
        band: CGRect,
        viewport: CGSize,
        progress: CGFloat
    ) -> CGSize {
        let clamped = min(max(progress, 0), 1)
        let bandFill = aspectFillSize(mediaAspect: mediaAspect, in: band.size)
        let viewportFill = aspectFillSize(mediaAspect: mediaAspect, in: viewport)
        return CGSize(
            width: bandFill.width + (viewportFill.width - bandFill.width) * clamped,
            height: bandFill.height + (viewportFill.height - bandFill.height) * clamped
        )
    }

    nonisolated static func aspectFillSize(mediaAspect: CGFloat, in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0, mediaAspect > 0 else { return .zero }
        let containerAspect = container.width / container.height
        if mediaAspect > containerAspect {
            let height = container.height
            return CGSize(width: height * mediaAspect, height: height)
        }
        let width = container.width
        return CGSize(width: width, height: width / mediaAspect)
    }
}
