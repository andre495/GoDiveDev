import SwiftUI

/// Shimmering water gradient + optional miniature rising bubbles clipped above the depth profile line.
struct DiveDepthProfileChartWaterFillView: View {
    let areaPath: Path
    let plotSize: CGSize
    var revealProgress: CGFloat = 1
    var animates: Bool = true
    /// Rising bubble layer (tank **minimized** / landscape); omitted on portrait **large**.
    var showsBubbles: Bool = true
    /// **0…1** — fades the top portion of the water fill (minimized entrance).
    var topHalfFadeProgress: CGFloat = 0
    /// Height fraction affected by **`topHalfFadeProgress`** (default half the plot).
    var topHalfFadeHeightFraction: CGFloat =
        DiveTankOverviewHeroPresentation.minimizedWaterTopFadeHeightFraction

    var body: some View {
        ZStack {
            waterGradientLayer
            if showsBubbles {
                WaterBubbleBackground(
                    animationPaused: !animates,
                    intensity: .chartUnderfill,
                    showsBackdrop: false,
                    diagnosticsLabel: "ChartUnderfill"
                )
            }
        }
        .frame(width: plotSize.width, height: plotSize.height)
        .mask {
            areaPath
        }
        .mask(alignment: .leading) {
            Rectangle()
                .frame(width: max(1, plotSize.width * min(1, max(0, revealProgress))))
        }
        .mask {
            topHalfFadeMask
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topHalfFadeMask: some View {
        let fade = min(1, max(0, topHalfFadeProgress))
        let band = min(1, max(0.01, topHalfFadeHeightFraction))
        return LinearGradient(
            stops: [
                .init(color: Color.black.opacity(Double(1 - fade)), location: 0),
                .init(color: Color.black.opacity(Double(1 - fade)), location: band * 0.55),
                .init(color: .black, location: band),
                .init(color: .black, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var waterGradientLayer: some View {
        if animates {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
                shimmerGradient(phase: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            shimmerGradient(phase: 0)
        }
    }

    private func shimmerGradient(phase: TimeInterval) -> some View {
        let shallow = shimmerComponent(phase: phase, speed: 0.75, base: 0.62, amplitude: 0.14)
        let mid = shimmerComponent(phase: phase, speed: 0.55, base: 0.5, amplitude: 0.12)
        let deep = shimmerComponent(phase: phase, speed: 0.65, base: 0.78, amplitude: 0.12)
        return LinearGradient(
            colors: [
                AppTheme.Colors.surfaceGradientTop.opacity(shallow),
                AppTheme.Colors.accentLight.opacity(mid),
                AppTheme.Colors.surfaceGradientBottom.opacity(deep),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18 + 0.1 * shimmerWave(phase: phase, offset: 0)),
                    AppTheme.Colors.accentLight.opacity(0.1 + 0.08 * shimmerWave(phase: phase, offset: 0.7)),
                    Color.clear,
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
        }
    }

    private func shimmerComponent(
        phase: TimeInterval,
        speed: Double,
        base: Double,
        amplitude: Double
    ) -> Double {
        base + amplitude * (sin(phase * speed) * 0.5 + 0.5)
    }

    private func shimmerWave(phase: TimeInterval, offset: Double) -> Double {
        sin(phase * 0.9 + offset) * 0.5 + 0.5
    }
}
