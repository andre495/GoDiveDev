import SwiftUI

/// Opaque fade over scrolling logbook rows, under **`LogbookTopChrome`** (status bar + search / **+**).
struct LogbookTopChromeScrim: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Safe-area top + measured **`LogbookTopChrome`** height.
    let topObstructionHeight: CGFloat
    /// Fade tail below the chrome row into list content.
    var featherHeight: CGFloat = 52

    private var bandHeight: CGFloat { topObstructionHeight + featherHeight }

    var body: some View {
        Group {
            if reduceTransparency {
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
