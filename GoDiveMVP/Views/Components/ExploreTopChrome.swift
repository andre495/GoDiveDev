import SwiftUI

/// Explore top bar — action row, optional map search suggestions, then centered site scope toggle.
/// **Map:** Trip Planner (**leading**) + site search + list flip (**trailing**).
/// **List:** shortened site search + map flip (**trailing**).
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    @Binding var siteScope: ExploreSiteScope
    @Binding var siteSearchQuery: String
    @FocusState.Binding var isSiteSearchFocused: Bool
    let showsSiteSearch: Bool
    let showsSiteScopeToggle: Bool
    let siteSearchSuggestions: [ExploreDiveSiteSearchSuggestion]
    let showsMapSearchSuggestions: Bool
    let statusBarSafeAreaTop: CGFloat
    let onOpenTripPlanner: () -> Void
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

            if showsSiteScopeToggle {
                HStack {
                    Spacer(minLength: 0)
                    ExploreSiteScopeToggle(selection: $siteScope)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.sm)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
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
                mapModeSearchRow
            } else {
                mapModeActionsRow
            }

            if showsMapSearchSuggestions, !siteSearchSuggestions.isEmpty {
                ExploreDiveSiteSearchSuggestionsView(
                    suggestions: siteSearchSuggestions,
                    onSelect: onSelectSiteSearchSuggestion
                )
            }
        }
    }

    private var mapModeActionsRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            tripPlannerLink
            Spacer(minLength: 0)
            viewModeFlipButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var mapModeSearchRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            tripPlannerLink

            CatalogSearchField(
                text: $siteSearchQuery,
                isFocused: $isSiteSearchFocused,
                placeholder: "Search dive sites",
                accessibilityIdentifier: "exploreSiteSearchField"
            )
            .frame(maxWidth: .infinity)

            ZStack(alignment: .trailing) {
                viewModeFlipButton
                    .opacity(isSiteSearchFocused ? 0 : 1)
                    .allowsHitTesting(!isSiteSearchFocused)
                    .accessibilityHidden(isSiteSearchFocused)

                if isSiteSearchFocused {
                    Button(action: cancelMapSearch) {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .accessibilityIdentifier("exploreSearchCancel")
                }
            }
            .foregroundStyle(AppTheme.Colors.iconPrimary)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44, alignment: .trailing)
        }
        .animation(.easeInOut(duration: 0.2), value: isSiteSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    @ViewBuilder
    private var listModeRow: some View {
        if showsSiteSearch {
            CatalogListSearchChrome(
                searchText: $siteSearchQuery,
                isSearchFocused: $isSiteSearchFocused,
                placeholder: "Search dive sites",
                searchFieldAccessibilityIdentifier: "exploreSiteSearchField",
                cancelAccessibilityIdentifier: "exploreSearchCancel",
                onCancel: onClearMapSiteSearch,
                trailingActions: { viewModeFlipButton }
            )
        } else {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Spacer(minLength: 0)
                viewModeFlipButton
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .appTopChromeVerticalPadding()
        }
    }

    private var viewModeFlipButton: some View {
        ExploreViewModeFlipButton(viewMode: $viewMode)
            .foregroundStyle(AppTheme.Colors.iconPrimary)
    }

    private var tripPlannerLink: some View {
        Button(action: onOpenTripPlanner) {
            Image(systemName: TripPlannerPresentation.exploreChromeSystemImage)
        }
        .accessibilityLabel(TripPlannerPresentation.exploreChromeAccessibilityLabel)
        .accessibilityIdentifier("Explore.TripPlanner")
    }

    private func cancelMapSearch() {
        isSiteSearchFocused = false
        siteSearchQuery = ""
        onClearMapSiteSearch()
    }
}
