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
                AppTheme.Colors.surfaceElevated
                    .opacity(0.98)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Colors.surfaceElevated.opacity(0.96), location: 0.0),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.88), location: 0.28),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.62), location: 0.55),
                        .init(color: AppTheme.Colors.surfaceGradientTop.opacity(0.28), location: 0.78),
                        .init(color: Color.clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: bandHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
