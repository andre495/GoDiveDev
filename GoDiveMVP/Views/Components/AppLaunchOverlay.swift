import SwiftUI

/// In-app launch chrome matching **`LaunchScreen.storyboard`** (logo + **GoDive** title).
struct AppLaunchOverlay: View {
    var showsProgressIndicator: Bool = false

    var body: some View {
        ZStack {
            AppTheme.Colors.launchScreenBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("GoDiveLogoPin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .accessibilityHidden(true)

                Text("GoDive")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accent)

                if showsProgressIndicator {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .padding(.top, AppTheme.Spacing.sm)
                        .accessibilityLabel("Loading")
                }
            }
            .offset(y: -48)
        }
        .accessibilityIdentifier("AppLaunch.Overlay")
    }
}

#Preview {
    AppLaunchOverlay(showsProgressIndicator: true)
}
