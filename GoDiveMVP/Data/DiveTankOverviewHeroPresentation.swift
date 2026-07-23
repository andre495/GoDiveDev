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

    /// Trailing inset for the small cylinder on **minimized** (larger → cylinder sits further left).
    nonisolated static let minimizedTrailingInset: CGFloat = 56
    nonisolated static let minimizedChartHorizontalInset: CGFloat = 20
    nonisolated static let minimizedChartVerticalPadding: CGFloat = 16
    nonisolated static let minimizedChartMaxWidthFraction: CGFloat = 0.92
    nonisolated static let minimizedChartMaxHeightFraction: CGFloat = 0.88
    /// Plot width ÷ height when sizing the centered minimized chart.
    nonisolated static let minimizedChartAspectWidthOverHeight: CGFloat = 1.65
    /// **Minimized** + landscape — inset from both edges so Dynamic Island / side chrome clear the plot.
    nonisolated static let minimizedLandscapeChartHorizontalInset: CGFloat = 48
    nonisolated static let minimizedLandscapeChartVerticalPadding: CGFloat = 12
    nonisolated static let minimizedTankSummaryGapBeforeTank: CGFloat = 10
    /// Vertical space for left-aligned header-style gas summary (used + SAC + RMV).
    nonisolated static let minimizedTankGasSummaryHeight: CGFloat = 96
    nonisolated static let minimizedTopInsetBelowChrome: CGFloat = 8
    /// Extra downward shift for the small tank on the **minimized** detent.
    nonisolated static let minimizedAdditionalTopOffset: CGFloat = 56
    /// Portrait tank hero stack (PSI summary, cylinder, depth chart) — shift down in the hero band.
    nonisolated static let heroContentDownwardOffset: CGFloat = 40

    /// Matches **`DiveTankCylinderVisual`** frame width ÷ height.
    nonisolated static let cylinderLayoutWidthOverHeight: CGFloat = 0.34

    /// Half-line estimate for **`gasLabelCenterY`** below the cylinder (**`.headline`**).
    nonisolated static let gasLabelEstimatedHalfHeight: CGFloat = 14

    nonisolated static let heroDetentAnimationDuration: TimeInterval = 0.45

    /// Portrait **minimized** entrance — cylinder drain, profile lines, and PSI-used tally run together.
    nonisolated static let minimizedEntranceAnimationDuration: TimeInterval = 5

    nonisolated static func shouldPlayMinimizedEntranceAnimation(
        from oldDetent: DiveActivityOverviewDetent,
        to newDetent: DiveActivityOverviewDetent
    ) -> Bool {
        newDetent == .minimized && newDetent.heightFraction < oldDetent.heightFraction
    }

    /// Interpolates consumed cylinder pressure for the minimized gas summary tally.
    nonisolated static func displayedPsiConsumed(
        consumedPSI: Double,
        revealProgress: CGFloat
    ) -> Double {
        let clamped = min(1, max(0, revealProgress))
        return consumedPSI * Double(clamped)
    }

    /// Depth + gas polylines draw progressively when entering **minimized**.
    nonisolated static func profileLineRevealProgress(
        sheetDetent: DiveActivityOverviewDetent,
        minimizedRevealProgress: CGFloat
    ) -> CGFloat {
        sheetDetent == .minimized ? min(1, max(0, minimizedRevealProgress)) : 1
    }

    /// Defer landscape-only chart chrome (media markers, zoom) until after rotation settles.
    nonisolated static let landscapeChartChromeCommitDelay: Duration = .milliseconds(120)

    nonisolated static func scale(for detent: DiveActivityOverviewDetent) -> CGFloat {
        detent == .minimized ? minimizedScale : 1
    }

    /// Gas mix under the cylinder — **minimized** only (panel + chart carry gas context at **large**).
    nonisolated static func showsGasMixLabel(for detent: DiveActivityOverviewDetent) -> Bool {
        false
    }

    /// Depth mini-chart beside the small cylinder on the **minimized** detent.
    nonisolated static func showsMinimizedProfileChart(
        for detent: DiveActivityOverviewDetent,
        depthSampleCount: Int
    ) -> Bool {
        detent == .minimized && depthSampleCount >= 2
    }

    nonisolated static func isLandscapeLayout(layoutSize: CGSize) -> Bool {
        layoutSize.width > layoutSize.height
    }

    /// Small cylinder on the **minimized** detent (hidden in landscape so the profile can go edge-to-edge).
    nonisolated static func showsMinimizedCylinder(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool
    ) -> Bool {
        detent == .minimized && !isLandscape
    }

    nonisolated static func showsMinimizedTankGasSummary(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        startPSI: Double?,
        endPSI: Double?
    ) -> Bool {
        detent == .minimized
            && !isLandscape
            && DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: startPSI, endPSI: endPSI) != nil
    }

    /// Media thumbnails on the landscape full-screen profile (every detent).
    nonisolated static func showsMediaMarkersOnLandscapeProfile(isLandscape: Bool) -> Bool {
        isLandscape
    }

    /// Depth / pressure profile chart on the tank tab.
    nonisolated static func showsProfileChart(
        for detent: DiveActivityOverviewDetent,
        depthSampleCount: Int,
        isLandscape: Bool
    ) -> Bool {
        guard depthSampleCount >= 2 else { return false }
        if isLandscape {
            return true
        }
        return detent == .minimized || detent == .large
    }

    /// Pinch zoom and pan on the hero profile (landscape or portrait **large**). Media thumbnails use **`showsMediaMarkersOnLandscapeProfile`**.
    nonisolated static func showsInteractiveProfileChartChrome(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        depthSampleCount: Int
    ) -> Bool {
        guard depthSampleCount >= 2 else { return false }
        if isLandscape { return true }
        return detent == .large
    }

    /// Cylinder + gas label (portrait **minimized** only; **large** uses the depth chart in the hero band).
    nonisolated static func showsTankCylinderHero(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool
    ) -> Bool {
        guard !isLandscape else { return false }
        return showsMinimizedCylinder(for: detent, isLandscape: false)
    }

    /// Tank hero layer visible — profile chart and/or minimized cylinder stack.
    nonisolated static func showsTankHeroVisuals(
        for detent: DiveActivityOverviewDetent,
        depthSampleCount: Int,
        isLandscape: Bool
    ) -> Bool {
        if isLandscape {
            return depthSampleCount >= 2
        }
        if detent == .large {
            return showsProfileChart(for: detent, depthSampleCount: depthSampleCount, isLandscape: false)
        }
        return showsTankHero(for: detent)
    }

    /// Portrait **minimized** cue above the sheet grabber band.
    nonisolated static func showsRotatePhoneHint(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        depthSampleCount: Int
    ) -> Bool {
        showsMinimizedProfileChart(for: detent, depthSampleCount: depthSampleCount) && !isLandscape
    }

    nonisolated static func tankHeroBottomContentMargin(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent,
        bottomSafeInset: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        if isLandscape {
            return bottomSafeInset + minimizedLandscapeChartVerticalPadding
        }
        return DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutHeight,
            detent: detent,
            bottomSafeInset: bottomSafeInset
        )
    }

    /// Center point for the rotate hint between the portrait chart and the sheet.
    nonisolated static func minimizedPortraitRotateHintCenter(
        layoutSize: CGSize,
        chartFrame: CGRect,
        layoutHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> CGPoint {
        let bandBottom = layoutHeight - bottomContentMargin
        let y = (chartFrame.maxY + bandBottom) / 2
        return CGPoint(x: layoutSize.width / 2, y: y)
    }

    /// Two-line gas summary to the left of the minimized cylinder.
    nonisolated static func minimizedTankGasSummaryFrame(
        layoutSize: CGSize,
        metrics: TankHeroLayoutMetrics,
        cylinderHeight: CGFloat
    ) -> CGRect {
        let scaledWidth = cylinderHeight * cylinderLayoutWidthOverHeight * metrics.scale
        let tankLeft = metrics.cylinderCenterX - scaledWidth / 2
        let right = tankLeft - minimizedTankSummaryGapBeforeTank
        let left = minimizedChartHorizontalInset
        let width = max(right - left, 0)
        let height: CGFloat = minimizedTankGasSummaryHeight
        let y = metrics.cylinderCenterY - height / 2
        return CGRect(x: left, y: y, width: width, height: height)
    }

    /// Plot frame in the visible band above the overview sheet (portrait vs landscape).
    nonisolated static func minimizedProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        isLandscape: Bool,
        detent: DiveActivityOverviewDetent = .minimized
    ) -> CGRect {
        if isLandscape {
            return minimizedLandscapeProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstructionHeight,
                bottomContentMargin: bottomContentMargin
            )
        }
        return minimizedPortraitProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            detent: detent
        )
    }

    /// Portrait **minimized** or **large** — centered plot in the hero band above the sheet.
    nonisolated static func minimizedPortraitProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        detent: DiveActivityOverviewDetent = .minimized
    ) -> CGRect {
        let bandTop = topObstructionHeight + minimizedChartVerticalPadding
        let bandBottom = layoutHeight - bottomContentMargin - minimizedChartVerticalPadding
        let availableHeight = max(bandBottom - bandTop, 0)
        let availableWidth = max(layoutSize.width - minimizedChartHorizontalInset * 2, 0)

        var width = availableWidth * minimizedChartMaxWidthFraction
        var height = width / minimizedChartAspectWidthOverHeight
        if height > availableHeight * minimizedChartMaxHeightFraction {
            height = availableHeight * minimizedChartMaxHeightFraction
            width = height * minimizedChartAspectWidthOverHeight
        }

        let x = (layoutSize.width - width) / 2
        let centeredY = bandTop + (availableHeight - height) / 2
        let downwardBias = detent == .minimized ? heroContentDownwardOffset : 0
        let y = min(centeredY + downwardBias, bandBottom - height)
        return CGRect(x: x, y: max(y, bandTop), width: width, height: height)
    }

    /// Landscape **minimized** — full-width plot; gas summary and cylinder are hidden.
    nonisolated static func minimizedLandscapeProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> CGRect {
        let bandTop = topObstructionHeight + minimizedLandscapeChartVerticalPadding
        let bandBottom = layoutHeight - bottomContentMargin - minimizedLandscapeChartVerticalPadding
        let height = max(bandBottom - bandTop, 0)
        let width = max(layoutSize.width - minimizedLandscapeChartHorizontalInset * 2, 0)
        let x = (layoutSize.width - width) / 2
        return CGRect(x: x, y: bandTop, width: width, height: height)
    }

    /// Portrait minimized cylinder + chart stack (hidden at **large** — chart-only hero).
    nonisolated static func showsTankHero(for detent: DiveActivityOverviewDetent) -> Bool {
        detent == .minimized
    }

    nonisolated static func layoutDetent(for detent: DiveActivityOverviewDetent) -> DiveActivityOverviewDetent {
        detent
    }

    /// **Large** always shows a full cylinder; **minimized** uses **`animatedFillFraction`** (PSI drain).
    nonisolated static func displayPressureFillFraction(
        sheetDetent: DiveActivityOverviewDetent,
        animatedFillFraction: CGFloat
    ) -> CGFloat {
        sheetDetent == .large ? 1 : animatedFillFraction
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
            top: topObstructionHeight
                + minimizedTopInsetBelowChrome
                + minimizedAdditionalTopOffset
                + heroContentDownwardOffset,
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
        case .large:
            let yOffset = verticalCenterOffset(
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstructionHeight,
                bottomContentMargin: bottomContentMargin,
                sheetHeightFraction: detent.heightFraction
            )
            let heroBandMidY = (layoutHeight - bottomContentMargin) / 2
            centerX = layoutSize.width / 2
            centerY = heroBandMidY + yOffset + heroContentDownwardOffset
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
