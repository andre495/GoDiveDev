import CoreGraphics
import Foundation
import SwiftUI

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

    /// Portrait **minimized** entrance — depth/gas lines + underfill wipe + PSI-used tally.
    nonisolated static let minimizedEntranceAnimationDuration: TimeInterval = 2.4

    /// After snap to **minimized** — top-half water fade + cylinder / PSI chrome fade-in.
    nonisolated static let minimizedWaterTopFadeDuration: TimeInterval = 0.35

    /// Fraction of plot height whose water fill fades on the minimized entrance.
    nonisolated static let minimizedWaterTopFadeHeightFraction: CGFloat = 0.5

    nonisolated static func shouldPlayMinimizedEntranceAnimation(
        from oldDetent: DiveActivityOverviewDetent,
        to newDetent: DiveActivityOverviewDetent
    ) -> Bool {
        newDetent == .minimized && newDetent.heightFraction < oldDetent.heightFraction
    }

    /// Snappy ease-out for water / chrome fade-in after snap.
    nonisolated static var minimizedWaterTopFadeAnimation: Animation {
        .easeOut(duration: minimizedWaterTopFadeDuration)
    }

    /// Snappy ease-out for depth/gas line + underfill wipe + PSI tally.
    nonisolated static var minimizedEntranceLineAnimation: Animation {
        .easeOut(duration: minimizedEntranceAnimationDuration)
    }

    /// **0** at **large**, **1** at **minimized** — from live sheet height while dragging.
    nonisolated static func collapseProgress(
        liveHeightFraction: CGFloat,
        layoutContext: DiveActivityOverviewSheetLayoutContext
    ) -> CGFloat {
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: layoutContext)
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let range = large - minimized
        guard range > 0.0001 else { return 0 }
        return min(max((large - liveHeightFraction) / range, 0), 1)
    }

    /// Collapse progress at which depth/gas strokes + under-curve fill are fully gone (lower = faster fade).
    nonisolated static let profileStrokeFadeCompleteCollapseProgress: CGFloat = 0.22

    /// Skip the post-snap line wipe when the user already dragged most of the way to **minimized**.
    nonisolated static let minimizedEntranceSkipCollapseThreshold: CGFloat = 0.88

    nonisolated static func shouldSkipMinimizedEntranceAfterDrag(
        liveHeightFraction: CGFloat,
        layoutContext: DiveActivityOverviewSheetLayoutContext
    ) -> Bool {
        collapseProgress(
            liveHeightFraction: liveHeightFraction,
            layoutContext: layoutContext
        ) >= minimizedEntranceSkipCollapseThreshold
    }

    /// Depth + gas stroke / dark underfill opacity while collapsing from **large** (fades out early on pull-down).
    nonisolated static func profileStrokeAndUnderfillOpacity(
        sheetDetent: DiveActivityOverviewDetent,
        collapseProgress: CGFloat
    ) -> CGFloat {
        if sheetDetent == .minimized {
            return 1
        }
        let t = min(1, max(0, collapseProgress))
        let completeBy = max(profileStrokeFadeCompleteCollapseProgress, 0.05)
        return min(1, max(0, 1 - t / completeBy))
    }

    /// Cylinder + PSI summary opacity on **minimized** (fades out while dragging toward **large**).
    nonisolated static func minimizedChromeOpacity(
        sheetDetent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        collapseProgress: CGFloat,
        chromeRevealProgress: CGFloat
    ) -> CGFloat {
        guard !isLandscape, sheetDetent == .minimized else { return 0 }
        let collapse = min(1, max(0, collapseProgress))
        let chrome = min(1, max(0, chromeRevealProgress))
        return collapse * chrome
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

    /// Water top-half fade after snap to **minimized** (**0** = full water, **1** = top half gone).
    nonisolated static func waterTopHalfFadeProgress(
        sheetDetent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        fadeProgress: CGFloat
    ) -> CGFloat {
        guard !isLandscape, sheetDetent == .minimized else { return 0 }
        return min(1, max(0, fadeProgress))
    }

    /// Gap above the translating chart filled with water while collapsing (**1** − top-fade).
    nonisolated static func collapseWaterBackdropOpacity(
        collapseProgress: CGFloat,
        waterTopHalfFadeProgress: CGFloat
    ) -> CGFloat {
        let collapse = min(1, max(0, collapseProgress))
        let topFade = min(1, max(0, waterTopHalfFadeProgress))
        return collapse * (1 - topFade)
    }

    /// Defer landscape-only chart chrome (media markers, zoom) until after rotation settles.
    nonisolated static let landscapeChartChromeCommitDelay: Duration = .milliseconds(120)

    /// Bubbles on the depth chart — portrait **minimized** and **landscape** only (not portrait **large**).
    nonisolated static func showsAnimatedDepthChartBubbles(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool
    ) -> Bool {
        isLandscape || detent == .minimized
    }

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

    /// Portrait **minimized** cue on the embedded sheet's upper trailing corner.
    nonisolated static func showsRotatePhoneHint(
        for detent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        depthSampleCount: Int
    ) -> Bool {
        showsMinimizedProfileChart(for: detent, depthSampleCount: depthSampleCount) && !isLandscape
    }

    nonisolated static func tankHeroBottomContentMargin(
        layoutContext: DiveActivityOverviewSheetLayoutContext,
        detent: DiveActivityOverviewDetent,
        isLandscape: Bool,
        liveHeightFraction: CGFloat? = nil
    ) -> CGFloat {
        DiveActivityOverviewLandscapePresentation.mapBottomContentMargin(
            layoutContext: layoutContext,
            detent: detent,
            liveHeightFraction: liveHeightFraction,
            isLandscape: isLandscape
        )
    }

    nonisolated static func tankHeroBottomContentMargin(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent,
        bottomSafeInset: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        tankHeroBottomContentMargin(
            layoutContext: DiveActivityOverviewSheetLayoutContext(
                layoutHeight: layoutHeight,
                screenWidth: DiveActivityOverviewDetent.presentationReferenceScreenWidth,
                topSafeInset: DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset,
                bottomSafeInset: bottomSafeInset
            ),
            detent: detent,
            isLandscape: isLandscape
        )
    }

    /// Below the embedded grabber row inside the minimized sheet band.
    nonisolated static let minimizedPortraitRotateHintTopInset: CGFloat =
        DiveActivityOverviewPanelMetrics.embeddedGrabberRowHeight + 4

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
        detent: DiveActivityOverviewDetent = .minimized,
        chartSizingBottomContentMargin: CGFloat? = nil,
        collapseProgress: CGFloat? = nil
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
            detent: detent,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin
                ?? bottomContentMargin,
            collapseProgress: collapseProgress
        )
    }

    /// Portrait **large** and **minimized** — base size from **large**; height scales up toward **minimized**.
    nonisolated static func minimizedPortraitProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        detent: DiveActivityOverviewDetent = .minimized,
        chartSizingBottomContentMargin: CGFloat? = nil,
        collapseProgress: CGFloat? = nil
    ) -> CGRect {
        if let collapseProgress {
            return interpolatedPortraitProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstructionHeight,
                bottomContentMargin: bottomContentMargin,
                chartSizingBottomContentMargin: chartSizingBottomContentMargin ?? bottomContentMargin,
                collapseProgress: collapseProgress
            )
        }
        let heightScale = portraitChartHeightScale(
            detent: detent,
            collapseProgress: nil
        )
        return portraitProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin ?? bottomContentMargin,
            heightScale: heightScale
        )
    }

    /// Top of the edge-to-edge profile plot — flush with the physical top of the hero (tab chrome overlays).
    nonisolated static let profileChartBandTop: CGFloat = 0

    /// Portrait tank profile — nudge the plot slightly below the sheet seam (under rounded panel corners).
    nonisolated static let largeDetentSheetSeamCornerBleed: CGFloat = 8

    /// Soft top fade on portrait tank chart (large + minimized + while dragging).
    nonisolated static let portraitChartTopFadeFraction: CGFloat = 0.14

    /// Back-compat alias — same soft top fade used for scrub callout pinning.
    nonisolated static let minimizedPortraitChartTopFadeFraction: CGFloat = portraitChartTopFadeFraction

    /// Minimized chart height ÷ large resting chart height (**~60% taller**).
    nonisolated static let minimizedPortraitChartHeightScale: CGFloat = 1.6

    /// Interpolates chart height scale from **large** (**1**) → **minimized** (**`minimizedPortraitChartHeightScale`**).
    nonisolated static func portraitChartHeightScale(
        detent: DiveActivityOverviewDetent,
        collapseProgress: CGFloat? = nil
    ) -> CGFloat {
        if let collapseProgress {
            let t = min(1, max(0, collapseProgress))
            return 1 + (minimizedPortraitChartHeightScale - 1) * t
        }
        return detent == .minimized ? minimizedPortraitChartHeightScale : 1
    }

    /// Portrait profile plot dimensions at the **large** resting detent — fixed while the grabber moves the sheet.
    nonisolated static func portraitLargeDetentProfileChartSize(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        chartSizingBottomContentMargin: CGFloat
    ) -> CGSize {
        let bandBottom = layoutHeight - chartSizingBottomContentMargin
        return CGSize(
            width: layoutSize.width,
            height: max(bandBottom - profileChartBandTop, 1)
        )
    }

    /// Portrait plot frame — base **large** size × **`heightScale`**; bottom tracks the live sheet seam.
    nonisolated static func portraitProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        chartSizingBottomContentMargin: CGFloat,
        heightScale: CGFloat = 1
    ) -> CGRect {
        let baseSize = portraitLargeDetentProfileChartSize(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin
        )
        let seamY = layoutHeight - bottomContentMargin
        let maxHeight = max(seamY - profileChartBandTop + largeDetentSheetSeamCornerBleed, 1)
        let scaledHeight = baseSize.height * max(heightScale, 0.01)
        var height = min(scaledHeight, maxHeight)
        var y = seamY - height + largeDetentSheetSeamCornerBleed
        if y < profileChartBandTop {
            y = profileChartBandTop
            height = max(min(scaledHeight, seamY - profileChartBandTop + largeDetentSheetSeamCornerBleed), 1)
        }
        return CGRect(
            x: 0,
            y: y,
            width: baseSize.width,
            height: height
        )
    }

    /// Smooth portrait chart frame while dragging — linear blend between **large** and **minimized** resting sizes.
    nonisolated static func interpolatedPortraitProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        chartSizingBottomContentMargin: CGFloat,
        collapseProgress: CGFloat
    ) -> CGRect {
        let t = min(1, max(0, collapseProgress))
        let large = portraitProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin,
            heightScale: 1
        )
        let minimized = portraitProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin,
            heightScale: minimizedPortraitChartHeightScale
        )
        return CGRect(
            x: large.minX + (minimized.minX - large.minX) * t,
            y: large.minY + (minimized.minY - large.minY) * t,
            width: large.width + (minimized.width - large.width) * t,
            height: large.height + (minimized.height - large.height) * t
        )
    }

    /// Render-server transform for the portrait chart while the grabber moves — the chart stays
    /// mounted at its resting **`baseFrame`** (no layout / path rebuilds per frame) and is
    /// y-scaled + repositioned to match **`targetFrame`**.
    struct PortraitChartDragTransform: Equatable, Sendable {
        let scaleY: CGFloat
        let centerY: CGFloat
    }

    nonisolated static func portraitChartDragTransform(
        baseFrame: CGRect,
        targetFrame: CGRect
    ) -> PortraitChartDragTransform {
        PortraitChartDragTransform(
            scaleY: targetFrame.height / max(baseFrame.height, 1),
            centerY: targetFrame.midY
        )
    }

    /// Landscape — edge-to-edge plot band (sheet hidden; gas summary and cylinder are hidden).
    nonisolated static func minimizedLandscapeProfileChartFrame(
        layoutSize: CGSize,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> CGRect {
        let bandBottom = layoutHeight - bottomContentMargin
        return CGRect(
            x: 0,
            y: profileChartBandTop,
            width: layoutSize.width,
            height: max(bandBottom - profileChartBandTop, 1)
        )
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
