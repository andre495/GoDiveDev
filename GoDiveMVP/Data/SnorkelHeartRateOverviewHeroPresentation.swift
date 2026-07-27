import CoreGraphics

/// Layout for the snorkel **heart rate** tab full-bleed hero chart.
enum SnorkelHeartRateOverviewHeroPresentation: Sendable {
    nonisolated static let horizontalInset: CGFloat = 16
    nonisolated static let topPaddingBelowObstruction: CGFloat = 8
    nonisolated static let bottomPaddingAboveSheet: CGFloat = 16

    nonisolated static func chartContentInsets(
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> (top: CGFloat, horizontal: CGFloat, bottom: CGFloat) {
        (
            top: topObstructionHeight + topPaddingBelowObstruction,
            horizontal: horizontalInset,
            bottom: bottomContentMargin + bottomPaddingAboveSheet
        )
    }
}
