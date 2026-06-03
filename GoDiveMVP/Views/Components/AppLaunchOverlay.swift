import SwiftUI

/// In-app launch chrome matching **`LaunchScreen.storyboard`** (logo + **GoDive** title).
struct AppLaunchOverlay: View {
    var showsProgressIndicator: Bool = false

    var body: some View {
        GeometryReader { geo in
            let safeMidY = AppLaunchLayout.safeAreaMidY(
                viewHeight: geo.size.height,
                safeAreaTop: geo.safeAreaInsets.top,
                safeAreaBottom: geo.safeAreaInsets.bottom
            )
            let logoCenterY = AppLaunchLayout.logoCenterY(safeAreaMidY: safeMidY)
            let titleCenterY = AppLaunchLayout.titleCenterY(logoCenterY: logoCenterY)
            let centerX = geo.size.width / 2

            ZStack {
                launchScreenBackground
                    .ignoresSafeArea()

                Image("GoDiveLogoPin")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: AppLaunchLayout.logoSize,
                        height: AppLaunchLayout.logoSize
                    )
                    .position(x: centerX, y: logoCenterY)
                    .accessibilityHidden(true)

                Text("GoDive")
                    .font(.system(size: AppLaunchLayout.titleFontSize, weight: .bold))
                    .foregroundStyle(launchTitleColor)
                    .position(x: centerX, y: titleCenterY)

                if showsProgressIndicator {
                    ProgressView()
                        .tint(launchTitleColor)
                        .position(
                            x: centerX,
                            y: AppLaunchLayout.progressCenterY(titleCenterY: titleCenterY)
                        )
                        .accessibilityLabel("Loading")
                }
            }
        }
        .accessibilityIdentifier("AppLaunch.Overlay")
    }

    private var launchScreenBackground: Color {
        Color(
            red: AppLaunchLayout.fixedBackgroundRed,
            green: AppLaunchLayout.fixedBackgroundGreen,
            blue: AppLaunchLayout.fixedBackgroundBlue
        )
    }

    private var launchTitleColor: Color {
        Color(
            red: AppLaunchLayout.fixedTitleRed,
            green: AppLaunchLayout.fixedTitleGreen,
            blue: AppLaunchLayout.fixedTitleBlue
        )
    }
}

#Preview {
    AppLaunchOverlay(showsProgressIndicator: true)
}
