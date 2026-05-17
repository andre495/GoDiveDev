import SwiftUI

/// Stable root for UI tests: no SwiftData, MapKit, canvas animations, or post-launch view swaps
/// (swapping roots drops the accessibility server and causes **`kAXErrorServerNotFound`**).
struct GoDiveUITestRootView: View {
    var body: some View {
        TabView {
            uiTestHomeTab
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            uiTestPlaceholderTab(title: "Logbook")
                .tabItem {
                    Label("Logbook", systemImage: "book.closed")
                }

            uiTestPlaceholderTab(title: "Field Guide")
                .tabItem {
                    Label("Field Guide", systemImage: "leaf")
                }

            uiTestPlaceholderTab(title: "Explore")
                .tabItem {
                    Label("Explore", systemImage: "map")
                }
        }
        .accessibilityIdentifier("GoDive.UITest.Root")
        .tint(AppTheme.Colors.tabSelected)
    }

    private var uiTestHomeTab: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AppTheme.Colors.screenBackgroundGradient
                    .ignoresSafeArea()

                AppHeader(title: "Home", showsBackButton: false, statusBarSafeAreaTop: proxy.safeAreaInsets.top) {
                    Button(action: {}) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profile")
                }
            }
        }
    }

    private func uiTestPlaceholderTab(title: String) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.screenBackgroundGradient)
            .accessibilityLabel(title)
    }
}
