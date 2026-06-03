import SwiftUI

/// Opaque fade over scrolling logbook rows, under **`LogbookTopChrome`** (status bar + search / **+**).
struct LogbookTopChromeScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Safe-area top + measured **`LogbookTopChrome`** height.
    let topObstructionHeight: CGFloat

    /// Fade below the chrome row into list content.
    private var feather: CGFloat { 52 }

    private var bandHeight: CGFloat { topObstructionHeight + feather }

    var body: some View {
        Group {
            if reduceTransparency {
                AppTheme.Colors.statusBarEdgeScrimSolid
                    .opacity(0.98)
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
