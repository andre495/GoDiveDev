import SwiftUI

/// Dark chrome fade from the top of the screen through the dive tab row — darkest at top, lighter toward the hero.
struct DiveOverviewMapTopScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Safe area top + back / tab toolbar row (**`DiveActivityOverviewPanelMetrics.mapTopObstructionHeight`**).
    let topObstructionHeight: CGFloat

    /// Fade below the toolbar into map / media / tank hero content.
    private var feather: CGFloat { 56 }

    private var bandHeight: CGFloat { topObstructionHeight + feather }

    var body: some View {
        Group {
            if reduceTransparency {
                Color.black.opacity(0.9)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.9), location: 0.0),
                        .init(color: Color.black.opacity(0.78), location: 0.22),
                        .init(color: Color.black.opacity(0.52), location: 0.48),
                        .init(color: Color.black.opacity(0.22), location: 0.76),
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
