import SwiftUI

/// Explore top bar — map/list flip and add dive site (no inline search).
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    @Binding var siteScope: ExploreSiteScope
    let showsSiteScopeToggle: Bool
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
            ZStack {
                HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                    viewModeFlipButton
                    Spacer(minLength: 0)
                    addDiveSiteButton
                }

                if showsSiteScopeToggle {
                    ExploreSiteScopeToggle(selection: $siteScope)
                }
            }
            .appGlassChromeControlRowHeight()
            .appHeaderChromeIconForeground()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var viewModeFlipButton: some View {
        ExploreViewModeFlipButton(viewMode: $viewMode)
    }

    private var addDiveSiteButton: some View {
        Button(action: onAddDiveSite) {
            Image(systemName: ExploreDiveSiteAddPresentation.chromeSystemImage)
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel(ExploreDiveSiteAddPresentation.chromeAccessibilityLabel)
        .accessibilityIdentifier(ExploreDiveSiteAddPresentation.chromeAccessibilityIdentifier)
    }
}
