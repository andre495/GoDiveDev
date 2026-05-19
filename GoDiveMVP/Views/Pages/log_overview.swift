import SwiftUI

struct LogOverviewView: View {
    @Environment(AccountSession.self) private var accountSession
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private enum Layout {
        /// ~1.5× prior **32** pt header avatar for easier recognition.
        static let profileAvatarDiameter: CGFloat = 48
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    if !GoDiveUITestConfiguration.isActive {
                        WaterBubbleBackground()
                    }

                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: headerClearance)

                                VStack {
                                    Spacer(minLength: AppTheme.Spacing.lg)

                                    AppComingSoonPlaceholder(
                                        systemImage: "sparkles",
                                        message: "Trip highlights, stats, and more home features are on the way."
                                    )

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - headerClearance))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AppHeader(title: "Home", showsBackButton: false, statusBarSafeAreaTop: proxy.safeAreaInsets.top) {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            ProfileAvatarView(
                                profilePhoto: accountSession.currentProfile?.profilePhoto,
                                diameter: Layout.profileAvatarDiameter
                            )
                            .frame(minWidth: Layout.profileAvatarDiameter, minHeight: Layout.profileAvatarDiameter)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile")
                        .accessibilityIdentifier("Home.ProfileLink")
                    }
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.Colors.screenBackgroundGradient
                    .ignoresSafeArea()
            }
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationInteractivePopGestureForHiddenNavBar()
        }
    }
}

#Preview {
    LogOverviewView()
}
