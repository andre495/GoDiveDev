import SwiftUI

/// Small animated cue that the tank profile expands in landscape.
struct DiveTankRotatePhoneHintView: View {
    @State private var isSideways = false

    var body: some View {
        Image(systemName: "iphone")
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .rotationEffect(.degrees(isSideways ? 90 : 0))
            .opacity(0.9)
            .accessibilityLabel("Rotate your phone sideways for the full dive profile and photos")
            .accessibilityIdentifier("DiveTank.RotatePhoneHint")
            .onAppear {
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    isSideways = true
                }
            }
    }
}
