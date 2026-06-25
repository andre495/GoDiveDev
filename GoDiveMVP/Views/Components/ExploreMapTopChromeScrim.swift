import SwiftUI

/// Deep ocean fade over **Explore** map content, under **`ExploreTopChrome`** (light mode).
struct ExploreMapTopChromeScrim: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Safe-area top + measured **`ExploreTopChrome`** height.
    let topObstructionHeight: CGFloat

    /// Fade below the chrome row into map imagery.
    private var feather: CGFloat { 52 }

    private var bandHeight: CGFloat { topObstructionHeight + feather }

    var body: some View {
        Group {
            if colorScheme == .light {
                if reduceTransparency {
                    AppTheme.Colors.exploreMapTopChromeScrimSolid
                } else {
                    AppTheme.Colors.exploreMapTopChromeScrimGradient
                }
            } else if reduceTransparency {
                AppTheme.Colors.listTopChromeScrimSolid
            } else {
                AppTheme.Colors.logbookTopChromeScrimGradient
            }
        }
        .frame(height: bandHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
