import SwiftUI

/// Semi-transparent fade over the top of the dive overview map so back + tab icons read on bright imagery.
struct DiveOverviewMapTopScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Safe area top + dive toolbar row (**`DiveActivityOverviewPanelMetrics.mapTopObstructionHeight`**).
    let topObstructionHeight: CGFloat

    /// Extra fade below the toolbar row into the map.
    private var feather: CGFloat { 36 }

    private var bandHeight: CGFloat { topObstructionHeight + feather }

    var body: some View {
        Group {
            if reduceTransparency {
                AppTheme.Colors.surfaceElevated
                    .opacity(0.94)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Colors.surfaceElevated.opacity(0.82), location: 0.0),
                        .init(color: AppTheme.Colors.surface.opacity(0.52), location: 0.48),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.18), location: 0.78),
                        .init(color: Color.clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: bandHeight)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
