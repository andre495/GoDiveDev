import SwiftUI

/// Brief centered checkmark after a successful activity delete (shown over the Logbook tab).
struct ActivityDeleteSuccessCheckmarkOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppTheme.Colors.accent)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .accessibilityLabel(ActivityDeleteSuccessPresentation.checkmarkAccessibilityLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.screenBackgroundGradient.ignoresSafeArea()
        ActivityDeleteSuccessCheckmarkOverlay()
    }
}
