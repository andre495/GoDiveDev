import SwiftUI

private enum LoggedOutMarketingChromeLayout {
    static let bubbleScrimOpacity: CGFloat = 0.42
}

/// Bubble background + readable scrim used on logged-out marketing / sign-in screens.
struct LoggedOutMarketingChrome<Content: View>: View {
    var bubbleAnimationPaused: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppHeaderlessPage {
            ZStack {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground(animationPaused: bubbleAnimationPaused)
                    AppTheme.Colors.surface
                        .opacity(LoggedOutMarketingChromeLayout.bubbleScrimOpacity)
                        .ignoresSafeArea()
                }

                content()
            }
        }
    }
}
