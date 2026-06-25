import SwiftUI

/// Explore top bar — action row and optional map search suggestions.
/// **Map / list:** map-list flip (**leading**) + add dive site (**trailing**); search row uses the same leading/trailing slots.
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    @Binding var siteSearchQuery: String
    @FocusState.Binding var isSiteSearchFocused: Bool
    let showsSiteSearch: Bool
    let siteSearchSuggestions: [ExploreDiveSiteSearchSuggestion]
    let showsMapSearchSuggestions: Bool
    let statusBarSafeAreaTop: CGFloat
    let onAddDiveSite: () -> Void
    let onSelectSiteSearchSuggestion: (ExploreDiveSiteSearchSuggestion) -> Void
    let onClearMapSiteSearch: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Group {
                switch viewMode {
                case .map:
                    mapModeChrome
                case .list:
                    listModeRow
                }
            }
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

    @ViewBuilder
    private var mapModeChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsSiteSearch {
                siteSearchRow
            } else {
                chromeActionsRow
            }

            if showsMapSearchSuggestions, !siteSearchSuggestions.isEmpty {
                ExploreDiveSiteSearchSuggestionsView(
                    suggestions: siteSearchSuggestions,
                    onSelect: onSelectSiteSearchSuggestion
                )
            }
        }
    }

    @ViewBuilder
    private var listModeRow: some View {
        if showsSiteSearch {
            siteSearchRow
        } else {
            chromeActionsRow
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

    private var siteSearchRow: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                viewModeFlipButton

                CatalogSearchField(
                    text: $siteSearchQuery,
                    isFocused: $isSiteSearchFocused,
                    placeholder: "Search dive sites",
                    accessibilityIdentifier: "exploreSiteSearchField"
                )
                .frame(maxWidth: .infinity)

                Group {
                    if isSiteSearchFocused {
                        CatalogSearchDismissButton(
                            action: cancelMapSearch,
                            accessibilityIdentifier: "exploreSearchCancel"
                        )
                    } else {
                        addDiveSiteButton
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .appGlassChromeControlRowHeight()
            }
            .appGlassChromeControlRowHeight()
        }
        .animation(.easeInOut(duration: 0.2), value: isSiteSearchFocused)
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

    private func cancelMapSearch() {
        isSiteSearchFocused = false
        siteSearchQuery = ""
        onClearMapSiteSearch()
    }
}
