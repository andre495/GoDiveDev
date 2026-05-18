import SwiftUI

/// Full-bleed hero behind the tank tab sheet — cylinder reframes per sheet detent.
struct DiveTankOverviewHeroView: View {
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    var sheetDetent: DiveActivityOverviewDetent = .medium
    var gasMixLabel: String = DiveGasMixImport.tankHeroNoGasSpecifiedLabel

    /// **0...1** — **`tankPressureEndPSI / tankPressureStartPSI`** when not on **medium** (animated on shorter detents).
    var pressureRemainingFraction: CGFloat = 1

    /// O₂ percent for yellow/green band split; **`nil`** → **21%** yellow (air).
    var oxygenMixPercent: Double?

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

    var body: some View {
        let cylinderHeight = DiveTankOverviewHeroPresentation.cylinderHeight(
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin
        )

        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            GeometryReader { geometry in
                let metrics = DiveTankOverviewHeroPresentation.layoutMetrics(
                    detent: DiveTankOverviewHeroPresentation.layoutDetent(for: sheetDetent),
                    layoutSize: geometry.size,
                    layoutHeight: layoutHeight,
                    topObstructionHeight: topObstructionHeight,
                    bottomContentMargin: bottomContentMargin,
                    cylinderHeight: cylinderHeight
                )

                Group {
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
        }
        .animation(
            .easeInOut(duration: DiveTankOverviewHeroPresentation.heroDetentAnimationDuration),
            value: sheetDetent
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        guard showsTankHero else { return "" }
        if showsGasMixLabel {
            return "Cylinder overview, \(gasMixLabel), full"
        }
        return "Cylinder overview"
    }
}
