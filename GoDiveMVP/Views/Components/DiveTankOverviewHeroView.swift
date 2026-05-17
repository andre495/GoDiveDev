import SwiftUI

/// Full-bleed hero behind the tank tab sheet — cylinder centered above the panel obstruction.
struct DiveTankOverviewHeroView: View {
    let bottomContentMargin: CGFloat
    let layoutHeight: CGFloat

    /// **0...1** — **`tankPressureEndPSI / tankPressureStartPSI`** visual (animated from grabber interaction).
    var pressureRemainingFraction: CGFloat = 1

    var body: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient
            DiveTankCylinderVisual(
                height: min(200, max(120, layoutHeight - bottomContentMargin - 96)),
                pressureRemainingFraction: pressureRemainingFraction
            )
            .opacity(0.92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, bottomContentMargin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cylinder overview")
    }
}
