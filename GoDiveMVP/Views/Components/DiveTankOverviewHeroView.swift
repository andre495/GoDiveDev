import SwiftUI

/// Full-bleed hero behind the tank tab sheet — cylinder reframes per sheet detent.
struct DiveTankOverviewHeroView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let layoutSize: CGSize
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    var sheetDetent: DiveActivityOverviewDetent = .medium
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

    @State private var landscapeChartChromeReady = false
    @State private var landscapeChartChromeTask: Task<Void, Never>?

    private var isLandscape: Bool {
        DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: layoutSize)
    }

    private var showsTankHero: Bool {
        DiveTankOverviewHeroPresentation.showsTankHero(for: sheetDetent)
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

    private var showsMinimizedProfileChart: Bool {
        DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(
            for: sheetDetent,
            depthSampleCount: depthSamples.count
        )
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

    private var showsLandscapeChartChrome: Bool {
        DiveTankOverviewHeroPresentation.showsMediaMarkersOnMinimizedProfile(
            for: sheetDetent,
            isLandscape: isLandscape
        ) && landscapeChartChromeReady
    }

    private var chartMediaMarkers: [DiveDepthProfileMediaMarker] {
        showsLandscapeChartChrome ? mediaMarkers : []
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

        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            Group {
                if showsMinimizedProfileChart {
                    let chartFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                        layoutSize: layoutSize,
                        layoutHeight: layoutHeight,
                        topObstructionHeight: topObstructionHeight,
                        bottomContentMargin: bottomContentMargin,
                        isLandscape: isLandscape
                    )
                    if DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
                        for: sheetDetent,
                        isLandscape: isLandscape,
                        depthSampleCount: depthSamples.count
                    ) {
                        let hintCenter = DiveTankOverviewHeroPresentation.minimizedPortraitRotateHintCenter(
                            layoutSize: layoutSize,
                            chartFrame: chartFrame,
                            layoutHeight: layoutHeight,
                            bottomContentMargin: bottomContentMargin
                        )
                        DiveTankRotatePhoneHintView()
                            .position(x: hintCenter.x, y: hintCenter.y)
                    }
                    DiveDepthProfileOverlayChart(
                        depthSamples: depthSamples,
                        pressureSamples: pressureSamples,
                        mediaMarkers: chartMediaMarkers,
                        mediaPhotosByID: mediaPhotosByID,
                        maxDepthHintMeters: maxDepthMeters,
                        pressureBaselinePSI: pressureBaselinePSI,
                        allowsZoomAndPan: showsLandscapeChartChrome,
                        onMediaMarkerTap: onMediaMarkerTap
                    )
                    .frame(width: chartFrame.width, height: chartFrame.height)
                    .position(x: chartFrame.midX, y: chartFrame.midY)
                    .accessibilityIdentifier("DiveTank.Hero.ProfileChart")
                }

                if sheetDetent == .medium || showsMinimizedCylinder {
                    DiveTankCylinderVisual(
                        height: cylinderHeight,
                        pressureRemainingFraction: displayFillFraction,
                        yellowFillFraction: DiveGasMixImport.tankYellowFillFraction(
                            oxygenMixPercent: oxygenMixPercent
                        )
                    )
                    .opacity(0.92)
                    .scaleEffect(metrics.scale, anchor: .center)
                    .position(x: metrics.cylinderCenterX, y: metrics.cylinderCenterY)
                }

                if showsMinimizedTankGasSummary, let consumed = psiConsumedPSI {
                    let summaryFrame = DiveTankOverviewHeroPresentation.minimizedTankGasSummaryFrame(
                        layoutSize: layoutSize,
                        metrics: metrics,
                        cylinderHeight: cylinderHeight
                    )
                    minimizedTankGasSummary(consumedPSI: consumed)
                        .frame(width: summaryFrame.width, height: summaryFrame.height, alignment: .topLeading)
                        .position(x: summaryFrame.midX, y: summaryFrame.midY)
                        .accessibilityIdentifier("DiveTank.Hero.GasSummary")
                }

                Text(gasMixLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showsGasMixLabel ? 1 : 0)
                    .position(x: metrics.cylinderCenterX, y: metrics.gasLabelCenterY)
                    .accessibilityHidden(!showsGasMixLabel)
            }
            .opacity(showsTankHero ? 1 : 0)
            .accessibilityHidden(!showsTankHero)
        }
        .animation(
            .easeInOut(duration: DiveTankOverviewHeroPresentation.heroDetentAnimationDuration),
            value: sheetDetent
        )
        .animation(nil, value: isLandscape)
        .onAppear {
            syncLandscapeChartChrome(isLandscape: isLandscape)
        }
        .onChange(of: isLandscape) { _, landscape in
            syncLandscapeChartChrome(isLandscape: landscape)
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
        if isLandscape {
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

    private func minimizedTankGasSummary(consumedPSI: Double) -> some View {
        let consumedText = DiveQuantityFormatting.cylinderPressure(
            fromPSI: consumedPSI,
            system: diveDisplayUnitSystem
        )
        return VStack(alignment: .leading, spacing: 6) {
            minimizedGasUsedLine(consumedText: consumedText)

            if let sacRateDisplay {
                minimizedGasMetricLine(
                    label: DiveTankMinimizedGasSummary.sacRateLabel,
                    value: sacRateDisplay,
                    font: .title3.weight(.semibold)
                )
            }

            if let rmvRateDisplay {
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

    private func minimizedGasUsedLine(consumedText: String) -> some View {
        HStack(spacing: 0) {
            Text(consumedText)
                .foregroundStyle(AppTheme.Colors.tankGasAccent)
            Text(" used.")
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
        guard showsTankHero else { return "" }
        if showsGasMixLabel {
            return "Cylinder overview, \(gasMixLabel), full"
        }
        if sheetDetent == .minimized {
            return "Depth profile with gas overlay"
        }
        return "Cylinder overview"
    }

}
