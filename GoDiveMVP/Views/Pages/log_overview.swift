import SwiftUI

struct LogOverviewView: View {
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

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
                            Image(systemName: "person.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile")
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
