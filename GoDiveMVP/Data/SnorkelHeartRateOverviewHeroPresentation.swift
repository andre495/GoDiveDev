import CoreGraphics

/// Layout for the snorkel **heart rate** tab full-bleed hero chart (parity with tank depth plot).
enum SnorkelHeartRateOverviewHeroPresentation: Sendable {
    /// Soft top fade so the plot dissolves under tab chrome (same token as tank depth).
    nonisolated static let portraitChartTopFadeFraction: CGFloat =
        DiveTankOverviewHeroPresentation.portraitChartTopFadeFraction

    /// Edge-to-edge plot band flush with the hero top and sheet seam (same geometry as tank depth).
    nonisolated static func chartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        sheetDetent: DiveActivityOverviewDetent,
        isLandscape: Bool
    ) -> CGRect {
        DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            isLandscape: isLandscape,
            detent: sheetDetent
        )
    }

    nonisolated static func scrubCalloutTopPadding(topObstructionHeight: CGFloat) -> CGFloat {
        DiveDepthProfileScrubCalloutPresentation.labelTopPadding(
            topObstructionHeight: topObstructionHeight
        )
    }
}
