import CoreGraphics
import Foundation

/// Animated frame for the tank hero cylinder (+ gas label anchor) at a resting detent.
struct TankHeroLayoutMetrics: Equatable, Sendable {
    let scale: CGFloat
    let cylinderCenterX: CGFloat
    let cylinderCenterY: CGFloat
    let gasLabelCenterY: CGFloat
}

/// Layout rules for the tank tab full-bleed hero (testable without SwiftUI).
enum DiveTankOverviewHeroPresentation: Sendable {
    /// Minimized detent — visual scale of the cylinder (**~half** size).
    nonisolated static let minimizedScale: CGFloat = 0.5

    nonisolated static let minimizedTrailingInset: CGFloat = 16
    nonisolated static let minimizedTopInsetBelowChrome: CGFloat = 8
    /// Extra downward shift for the small tank on the **minimized** detent.
    nonisolated static let minimizedAdditionalTopOffset: CGFloat = 56

    /// Matches **`DiveTankCylinderVisual`** frame width ÷ height.
    nonisolated static let cylinderLayoutWidthOverHeight: CGFloat = 0.34

    /// Half-line estimate for **`gasLabelCenterY`** below the cylinder (**`.headline`**).
    nonisolated static let gasLabelEstimatedHalfHeight: CGFloat = 14

    nonisolated static let heroDetentAnimationDuration: TimeInterval = 0.45

    /// Placeholder until dive-level gas mix is modeled on **`DiveActivity`**.
    nonisolated static let placeholderGasMixLabel = "Nitrox 33%"

    nonisolated static func scale(for detent: DiveActivityOverviewDetent) -> CGFloat {
        detent == .minimized ? minimizedScale : 1
    }

    nonisolated static func showsGasMixLabel(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .medium
    }

    /// Cylinder hero is hidden when the sheet covers the tab (**large**); returns on **medium** / **minimized**.
    nonisolated static func showsTankHero(for detent: DiveActivityOverviewDetent) -> Bool {
        detent != .large
    }

    /// **Large** keeps **medium** layout while the hero is hidden so expand/collapse only fades opacity.
    nonisolated static func layoutDetent(for detent: DiveActivityOverviewDetent) -> DiveActivityOverviewDetent {
        detent == .large ? .medium : detent
    }

    /// **Medium** always shows a full cylinder; shorter detents use **`animatedFillFraction`** (PSI drain).
    nonisolated static func displayPressureFillFraction(
        sheetDetent: DiveActivityOverviewDetent,
        animatedFillFraction: CGFloat
    ) -> CGFloat {
        sheetDetent == .medium ? 1 : animatedFillFraction
    }

    /// Base cylinder height before **`scale(for:)`**.
    nonisolated static func cylinderHeight(
        layoutHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> CGFloat {
        min(200, max(120, layoutHeight - bottomContentMargin - 96))
    }

    /// Shifts the centered tank from the padded-area midpoint to **`targetPinScreenYFraction`**.
    nonisolated static func verticalCenterOffset(
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        sheetHeightFraction: CGFloat
    ) -> CGFloat {
        let h = max(layoutHeight, 1)
        let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: h,
            topObstructionHeight: topObstructionHeight,
            sheetHeightFraction: sheetHeightFraction
        ) * h
        let defaultCenterY = (h - bottomContentMargin) / 2
        return targetY - defaultCenterY
    }

    nonisolated static func topTrailingPadding(
        topObstructionHeight: CGFloat
    ) -> (top: CGFloat, trailing: CGFloat) {
        (
            top: topObstructionHeight + minimizedTopInsetBelowChrome + minimizedAdditionalTopOffset,
            trailing: minimizedTrailingInset
        )
    }

    /// Explicit center + scale so **medium** ↔ **minimized** can animate smoothly (no alignment swap).
    nonisolated static func layoutMetrics(
        detent: DiveActivityOverviewDetent,
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        cylinderHeight: CGFloat
    ) -> TankHeroLayoutMetrics {
        let scale = scale(for: detent)
        let contentWidth = cylinderHeight * cylinderLayoutWidthOverHeight
        let scaledWidth = contentWidth * scale
        let scaledHeight = cylinderHeight * scale

        let centerX: CGFloat
        let centerY: CGFloat

        switch detent {
        case .minimized:
            let insets = topTrailingPadding(topObstructionHeight: topObstructionHeight)
            centerX = layoutSize.width - insets.trailing - scaledWidth / 2
            centerY = insets.top + scaledHeight / 2
        case .medium, .large:
            let yOffset = verticalCenterOffset(
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstructionHeight,
                bottomContentMargin: bottomContentMargin,
                sheetHeightFraction: detent.heightFraction
            )
            let heroBandMidY = (layoutHeight - bottomContentMargin) / 2
            centerX = layoutSize.width / 2
            centerY = heroBandMidY + yOffset
        }

        let labelGap: CGFloat = 8
        let gasLabelCenterY = centerY + scaledHeight / 2 + labelGap + gasLabelEstimatedHalfHeight

        return TankHeroLayoutMetrics(
            scale: scale,
            cylinderCenterX: centerX,
            cylinderCenterY: centerY,
            gasLabelCenterY: gasLabelCenterY
        )
    }
}
