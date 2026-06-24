import SwiftUI

/// Explore top bar — action row, optional map search suggestions, then centered site scope toggle.
/// **Map / list:** map-list flip (**leading**) + add dive site (**trailing**); search row uses the same leading/trailing slots.
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
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            viewModeFlipButton
            Spacer(minLength: 0)
            addDiveSiteButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var siteSearchRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            viewModeFlipButton

            CatalogSearchField(
                text: $siteSearchQuery,
                isFocused: $isSiteSearchFocused,
                placeholder: "Search dive sites",
                accessibilityIdentifier: "exploreSiteSearchField"
            )
            .frame(maxWidth: .infinity)

            ZStack(alignment: .trailing) {
                addDiveSiteButton
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
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44, alignment: .trailing)
        }
        .animation(.easeInOut(duration: 0.2), value: isSiteSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var viewModeFlipButton: some View {
        ExploreViewModeFlipButton(viewMode: $viewMode)
            .foregroundStyle(chromeActionForeground)
    }

    private var addDiveSiteButton: some View {
        Button(action: onAddDiveSite) {
            Image(systemName: ExploreDiveSiteAddPresentation.chromeSystemImage)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(chromeActionForeground)
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
