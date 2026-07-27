import SwiftUI

/// Shimmering water gradient + miniature rising bubbles clipped above the depth profile line.
struct DiveDepthProfileChartWaterFillView: View {
    let areaPath: Path
    let plotSize: CGSize
    var revealProgress: CGFloat = 1
    var animates: Bool = true

    var body: some View {
        ZStack {
            waterGradientLayer
            WaterBubbleBackground(
                animationPaused: !animates,
                intensity: .chartUnderfill,
                showsBackdrop: false
            )
        }
        .frame(width: plotSize.width, height: plotSize.height)
        .mask {
            areaPath
        }
        .mask(alignment: .leading) {
            Rectangle()
                .frame(width: max(1, plotSize.width * min(1, max(0, revealProgress))))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
