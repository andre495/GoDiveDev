import SwiftUI

/// Explore top bar — map/list flip and add dive site (no inline search).
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    let statusBarSafeAreaTop: CGFloat
    let onAddDiveSite: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            chromeActionsRow
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(
                    safeAreaTop: statusBarSafeAreaTop,
                    usesExploreMapChrome: viewMode == .map
                )
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }

    private var chromeActionsRow: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                viewModeFlipButton
                Spacer(minLength: 0)
                addDiveSiteButton
            }
            .appGlassChromeControlRowHeight()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var viewModeFlipButton: some View {
        ExploreViewModeFlipButton(viewMode: $viewMode)
            .tint(chromeActionForeground)
    }

    private var addDiveSiteButton: some View {
        Button(action: onAddDiveSite) {
            Image(systemName: ExploreDiveSiteAddPresentation.chromeSystemImage)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .tint(chromeActionForeground)
        .accessibilityLabel(ExploreDiveSiteAddPresentation.chromeAccessibilityLabel)
        .accessibilityIdentifier(ExploreDiveSiteAddPresentation.chromeAccessibilityIdentifier)
    }

    private var chromeActionForeground: Color {
        viewMode == .map ? .white : AppTheme.Colors.iconPrimary
    }
}
