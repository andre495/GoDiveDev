import SwiftUI

/// Static deep-water gradient clipped to the region below the depth profile line.
struct DiveDepthProfileChartStaticUnderfillView: View {
    let areaPath: Path
    let plotSize: CGSize
    /// **0...1** — left-to-right reveal (tank **minimized** entrance); water fill stays full underneath.
    var revealProgress: CGFloat = 1

    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.surfaceGradientTop.opacity(0.55),
                AppTheme.Colors.surfaceGradientBottom.opacity(0.94),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
}
