import SwiftUI

/// Full-bleed hero behind the tank tab sheet — cylinder reframes per sheet detent.
struct DiveTankOverviewHeroView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let layoutSize: CGSize
    let bottomContentMargin: CGFloat
    /// **Large**-detent sheet obstruction — fixed portrait chart dimensions while the grabber moves the seam.
    var chartSizingBottomContentMargin: CGFloat?
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    var sheetDetent: DiveActivityOverviewDetent = .large
    var gasMixLabel: String = DiveGasMixImport.tankHeroNoGasSpecifiedLabel

    /// **0...1** — **`tankPressureEndPSI / tankPressureStartPSI`** when not on **medium** (animated on shorter detents).
    var pressureRemainingFraction: CGFloat = 1

    /// O₂ percent for yellow/green band split; **`nil`** → **21%** yellow (air).
    var oxygenMixPercent: Double?

    var depthSamples: [DiveDepthProfileSample] = []
    var pressureSamples: [DiveDepthProfilePressureSample] = []
    var mediaMarkers: [DiveDepthProfileMediaMarker] = []
    var mediaPhotosByID: [UUID: DiveMediaPhoto] = [:]
    var onMediaMarkerTap: ((DiveDepthProfileMediaMarker) -> Void)? = nil
    var maxDepthMeters: Double = 1
    /// Gas-line **y = 0** (ending cylinder pressure).
    var pressureBaselinePSI: Double?
    var tankPressureStartPSI: Double?
    var tankPressureEndPSI: Double?
    /// Formatted SAC (**psi/min** or **bar/min**); **`nil`** hides the SAC line.
    var sacRateDisplay: String?
    /// Formatted RMV (**L/min** or **cu ft/min**); **`nil`** hides the RMV line.
    var rmvRateDisplay: String?
    /// **0...1** — depth + PSI profile lines draw left-to-right when entering **minimized**.
    var profileLineRevealProgress: CGFloat = 1
    /// **0...1** — minimized **PSI used** tally from zero.
    var psiUsedRevealProgress: CGFloat = 1
    /// Live overview sheet height fraction (drives collapse fades while dragging).
    var liveHeightFraction: CGFloat? = nil
    /// **0…1** — top-half water fade after snap to **minimized**.
    var waterTopHalfFadeProgress: CGFloat = 0
    /// **0…1** — cylinder + PSI chrome fade-in after snap to **minimized**.
    var minimizedChromeRevealProgress: CGFloat = 1

    @State private var landscapeChartChromeReady = false
    @State private var landscapeChartChromeTask: Task<Void, Never>?
    @Binding var scrubCallout: DiveDepthProfileScrubCallout?

    private var isLandscape: Bool {
        DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: layoutSize)
    }

    private var collapseProgress: CGFloat {
        DiveTankOverviewHeroPresentation.collapseProgress(
            liveHeightFraction: liveHeightFraction ?? sheetDetent.heightFraction,
            layoutContext: DiveActivityOverviewSheetLayoutContext.presentationReference
        )
    }

    private var profileStrokeAndUnderfillOpacity: CGFloat {
        DiveTankOverviewHeroPresentation.profileStrokeAndUnderfillOpacity(
            sheetDetent: sheetDetent,
            collapseProgress: collapseProgress
        )
    }

    private var resolvedWaterTopHalfFadeProgress: CGFloat {
        DiveTankOverviewHeroPresentation.waterTopHalfFadeProgress(
            sheetDetent: sheetDetent,
            isLandscape: isLandscape,
            fadeProgress: waterTopHalfFadeProgress
        )
    }

    private var minimizedChromeOpacity: CGFloat {
        DiveTankOverviewHeroPresentation.minimizedChromeOpacity(
            sheetDetent: sheetDetent,
            isLandscape: isLandscape,
            collapseProgress: collapseProgress,
            chromeRevealProgress: minimizedChromeRevealProgress
        )
    }

    private var showsTankHeroVisuals: Bool {
        DiveTankOverviewHeroPresentation.showsTankHeroVisuals(
            for: sheetDetent,
            depthSampleCount: depthSamples.count,
            isLandscape: isLandscape
        )
    }

    private var showsProfileChart: Bool {
        DiveTankOverviewHeroPresentation.showsProfileChart(
            for: sheetDetent,
            depthSampleCount: depthSamples.count,
            isLandscape: isLandscape
        )
    }

    private var showsTankCylinderHero: Bool {
        DiveTankOverviewHeroPresentation.showsTankCylinderHero(
            for: sheetDetent,
            isLandscape: isLandscape
        )
    }

    private var displayFillFraction: CGFloat {
        DiveTankOverviewHeroPresentation.displayPressureFillFraction(
            sheetDetent: sheetDetent,
            animatedFillFraction: pressureRemainingFraction
        )
    }

    private var showsGasMixLabel: Bool {
        DiveTankOverviewHeroPresentation.showsGasMixLabel(for: sheetDetent)
    }


    private var showsMinimizedTankGasSummary: Bool {
        DiveTankOverviewHeroPresentation.showsMinimizedTankGasSummary(
            for: sheetDetent,
            isLandscape: isLandscape,
            startPSI: tankPressureStartPSI,
            endPSI: tankPressureEndPSI
        )
    }

    private var showsMinimizedCylinder: Bool {
        DiveTankOverviewHeroPresentation.showsMinimizedCylinder(
            for: sheetDetent,
            isLandscape: isLandscape
        )
    }

    private var showsInteractiveChartChrome: Bool {
        DiveTankOverviewHeroPresentation.showsInteractiveProfileChartChrome(
            for: sheetDetent,
            isLandscape: isLandscape,
            depthSampleCount: depthSamples.count
        ) && landscapeChartChromeReady
    }

    private var chartProfileLineRevealProgress: CGFloat {
        DiveTankOverviewHeroPresentation.profileLineRevealProgress(
            sheetDetent: sheetDetent,
            minimizedRevealProgress: profileLineRevealProgress
        )
    }

    private var showsChartMediaMarkers: Bool {
        DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: isLandscape)
            && showsInteractiveChartChrome
    }

    private var chartMediaMarkers: [DiveDepthProfileMediaMarker] {
        showsChartMediaMarkers ? mediaMarkers : []
    }

    private var psiConsumedPSI: Double? {
        DiveTankMinimizedGasSummary.psiConsumedPSI(
            startPSI: tankPressureStartPSI,
            endPSI: tankPressureEndPSI
        )
    }

    var body: some View {
        let cylinderHeight = DiveTankOverviewHeroPresentation.cylinderHeight(
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin
        )
        let metrics = DiveTankOverviewHeroPresentation.layoutMetrics(
            detent: DiveTankOverviewHeroPresentation.layoutDetent(for: sheetDetent),
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            cylinderHeight: cylinderHeight
        )
        let chartFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            isLandscape: isLandscape,
            detent: sheetDetent,
            chartSizingBottomContentMargin: chartSizingBottomContentMargin,
            collapseProgress: isLandscape ? nil : collapseProgress
        )
        let backdropOpacity = DiveTankOverviewHeroPresentation.collapseWaterBackdropOpacity(
            collapseProgress: isLandscape ? 0 : collapseProgress,
            waterTopHalfFadeProgress: resolvedWaterTopHalfFadeProgress
        )
        let backdropHeight = max(0, chartFrame.minY)

        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            Group {
                if showsProfileChart, !isLandscape, backdropHeight > 0.5, backdropOpacity > 0.001 {
                    DiveTankCollapseWaterBackdrop()
                        .frame(width: layoutSize.width, height: backdropHeight)
                        .position(x: layoutSize.width / 2, y: backdropHeight / 2)
                        .opacity(Double(backdropOpacity))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                if showsProfileChart {
                    DiveDepthProfileOverlayChart(
                        depthSamples: depthSamples,
                        pressureSamples: pressureSamples,
                        mediaMarkers: chartMediaMarkers,
                        mediaPhotosByID: mediaPhotosByID,
                        maxDepthHintMeters: maxDepthMeters,
                        pressureBaselinePSI: pressureBaselinePSI,
                        profileLineRevealProgress: chartProfileLineRevealProgress,
                        profileStrokeAndUnderfillOpacity: profileStrokeAndUnderfillOpacity,
                        waterTopHalfFadeProgress: resolvedWaterTopHalfFadeProgress,
                        allowsZoomAndPan: showsInteractiveChartChrome,
                        showsWaterBubbles: DiveTankOverviewHeroPresentation.showsAnimatedDepthChartBubbles(
                            for: sheetDetent,
                            isLandscape: isLandscape
                        ),
                        topEdgeFadeFraction: isLandscape
                            ? 0
                            : DiveTankOverviewHeroPresentation.portraitChartTopFadeFraction,
                        horizontalEdgeBufferFraction: isLandscape
                            ? DiveDepthProfileChartPresentation.landscapeHorizontalEdgeBufferFraction
                            : 0,
                        chromeStyle: .edgeToEdge,
                        onMediaMarkerTap: onMediaMarkerTap,
                        scrubCalloutPinning: .pinnedUnderTabMenu(
                            topObstructionHeight: topObstructionHeight
                        ),
                        onScrubCalloutChange: { scrubCallout = $0 }
                    )
                    .frame(width: chartFrame.width, height: chartFrame.height)
                    .position(x: chartFrame.midX, y: chartFrame.midY)
                    .animation(nil, value: bottomContentMargin)
                    .accessibilityIdentifier("DiveTank.Hero.ProfileChart")
                }

                if showsTankCylinderHero {
                    DiveTankCylinderVisual(
                        height: cylinderHeight,
                        pressureRemainingFraction: displayFillFraction,
                        yellowFillFraction: DiveGasMixImport.tankYellowFillFraction(
                            oxygenMixPercent: oxygenMixPercent
                        )
                    )
                    .opacity(0.92 * Double(minimizedChromeOpacity))
                    .scaleEffect(metrics.scale, anchor: .center)
                    .position(x: metrics.cylinderCenterX, y: metrics.cylinderCenterY)
                    .accessibilityHidden(minimizedChromeOpacity < 0.05)
                }

                if showsMinimizedTankGasSummary, let consumed = psiConsumedPSI {
                    let summaryFrame = DiveTankOverviewHeroPresentation.minimizedTankGasSummaryFrame(
                        layoutSize: layoutSize,
                        metrics: metrics,
                        cylinderHeight: cylinderHeight
                    )
                    minimizedTankGasSummary(
                        totalConsumedPSI: consumed,
                        revealProgress: psiUsedRevealProgress
                    )
                        .frame(width: summaryFrame.width, height: summaryFrame.height, alignment: .topLeading)
                        .position(x: summaryFrame.midX, y: summaryFrame.midY)
                        .opacity(Double(minimizedChromeOpacity))
                        .animation(nil, value: sheetDetent)
                        .accessibilityIdentifier("DiveTank.Hero.GasSummary")
                        .accessibilityHidden(minimizedChromeOpacity < 0.05)
                }

                Text(gasMixLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showsGasMixLabel && !isLandscape ? 1 : 0)
                    .position(x: metrics.cylinderCenterX, y: metrics.gasLabelCenterY)
                    .accessibilityHidden(!showsGasMixLabel)
            }
            .opacity(showsTankHeroVisuals ? 1 : 0)
            .accessibilityHidden(!showsTankHeroVisuals)
        }
        .animation(
            .easeInOut(duration: DiveTankOverviewHeroPresentation.heroDetentAnimationDuration),
            value: sheetDetent
        )
        .animation(nil, value: isLandscape)
        .animation(nil, value: collapseProgress)
        .onAppear {
            syncLandscapeChartChrome(isLandscape: isLandscape)
        }
        .onChange(of: isLandscape) { _, landscape in
            syncLandscapeChartChrome(isLandscape: landscape)
        }
        .onChange(of: sheetDetent) { _, _ in
            syncLandscapeChartChrome(isLandscape: isLandscape)
        }
        .onDisappear {
            landscapeChartChromeTask?.cancel()
            landscapeChartChromeTask = nil
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabelText)
    }

    private func syncLandscapeChartChrome(isLandscape: Bool) {
        landscapeChartChromeTask?.cancel()
        let wantsInteractiveChrome = DiveTankOverviewHeroPresentation.showsInteractiveProfileChartChrome(
            for: sheetDetent,
            isLandscape: isLandscape,
            depthSampleCount: depthSamples.count
        )
        if wantsInteractiveChrome {
            landscapeChartChromeReady = false
            landscapeChartChromeTask = Task { @MainActor in
                try? await Task.sleep(
                    for: DiveTankOverviewHeroPresentation.landscapeChartChromeCommitDelay
                )
                guard !Task.isCancelled else { return }
                landscapeChartChromeReady = true
            }
        } else {
            landscapeChartChromeReady = false
        }
    }

    private func minimizedTankGasSummary(totalConsumedPSI: Double, revealProgress: CGFloat) -> some View {
        let tally = DiveTankMinimizedGasSummary.minimizedGasConsumedTally(
            totalConsumedPSI: totalConsumedPSI,
            revealProgress: revealProgress,
            system: diveDisplayUnitSystem
        )
        let consumedText = "\(tally.pressureValueText)\(tally.unitSuffix)"
        let showsSecondaryRates = revealProgress >= 0.999

        return VStack(alignment: .leading, spacing: 6) {
            minimizedGasUsedLine(
                totalConsumedPSI: totalConsumedPSI,
                revealProgress: revealProgress
            )

            if showsSecondaryRates, let sacRateDisplay {
                minimizedGasMetricLine(
                    label: DiveTankMinimizedGasSummary.sacRateLabel,
                    value: sacRateDisplay,
                    font: .title3.weight(.semibold)
                )
            }

            if showsSecondaryRates, let rmvRateDisplay {
                minimizedGasMetricLine(
                    label: DiveTankMinimizedGasSummary.rmvRateLabel,
                    value: rmvRateDisplay,
                    font: .title3.weight(.semibold)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(minimizedGasSummaryAccessibility(consumedText: consumedText))
    }

    private func minimizedGasUsedLine(
        totalConsumedPSI: Double,
        revealProgress: CGFloat
    ) -> some View {
        let unitSuffix = diveDisplayUnitSystem == .imperial ? " psi" : " bar"
        return HStack(spacing: 0) {
            MinimizedGasUsedCountText(
                revealProgress: revealProgress,
                totalConsumedPSI: totalConsumedPSI,
                unitSystem: diveDisplayUnitSystem
            )
            .foregroundStyle(AppTheme.Colors.tankGasAccent)
            .monospacedDigit()
            Text("\(unitSuffix) used.")
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .font(AppTheme.Typography.headerTitle.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minimizedGasMetricLine(label: String, value: String, font: Font) -> some View {
        HStack(spacing: 0) {
            Text("\(label) ")
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(value)
                .foregroundStyle(AppTheme.Colors.tankGasAccent)
        }
        .font(font)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minimizedGasSummaryAccessibility(consumedText: String) -> String {
        var parts = [DiveTankMinimizedGasSummary.usedLine(formattedConsumed: consumedText)]
        if let sacRateDisplay {
            parts.append(DiveTankMinimizedGasSummary.sacRateLine(formattedRate: sacRateDisplay))
        }
        if let rmvRateDisplay {
            parts.append(DiveTankMinimizedGasSummary.rmvRateLine(formattedRate: rmvRateDisplay))
        }
        return parts.joined(separator: ". ")
    }

    private var accessibilityLabelText: String {
        guard showsTankHeroVisuals else { return "" }
        if isLandscape {
            return "Depth profile with gas overlay"
        }
        if sheetDetent == .minimized || sheetDetent == .large {
            return "Depth profile with gas overlay"
        }
        return "Cylinder overview"
    }

}

/// Water fill that covers the gap above the translating tank chart while collapsing to **minimized**.
private struct DiveTankCollapseWaterBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.surfaceGradientTop.opacity(0.62),
                AppTheme.Colors.accentLight.opacity(0.5),
                AppTheme.Colors.surfaceGradientBottom.opacity(0.78),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    AppTheme.Colors.accentLight.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
        }
    }
}

/// Count-up PSI / bar used — interpolates with the tank **minimized** entrance progress.
private struct MinimizedGasUsedCountText: View, Animatable {
    var revealProgress: CGFloat
    let totalConsumedPSI: Double
    let unitSystem: DiveDisplayUnitSystem

    var animatableData: CGFloat {
        get { revealProgress }
        set { revealProgress = newValue }
    }

    var body: some View {
        let tally = DiveTankMinimizedGasSummary.minimizedGasConsumedTally(
            totalConsumedPSI: totalConsumedPSI,
            revealProgress: revealProgress,
            system: unitSystem
        )
        switch unitSystem {
        case .imperial:
            Text(tally.numericAnimationValue, format: .number.grouping(.automatic).precision(.fractionLength(0)))
        case .metric:
            Text(tally.numericAnimationValue, format: .number.precision(.fractionLength(1)))
        }
    }
}
