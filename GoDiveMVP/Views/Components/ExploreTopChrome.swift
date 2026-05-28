import SwiftUI

/// Explore top bar — one row, logbook-height chrome.
/// **Map:** Trip Planner (**leading**) + map/list toggle (**trailing**).
/// **List:** site search inline with map/list toggle (**trailing**); no calendar.
struct ExploreTopChrome: View {
    @Binding var viewMode: ExploreViewMode
    @Binding var siteSearchQuery: String
    @FocusState.Binding var isSiteSearchFocused: Bool
    let showsSiteSearch: Bool
    let statusBarSafeAreaTop: CGFloat

    var body: some View {
        Group {
            switch viewMode {
            case .map:
                mapModeRow
            case .list:
                listModeRow
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

    private var mapModeRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            tripPlannerLink
            Spacer(minLength: 0)
            viewModeToggle
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
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
                trailingActions: { viewModeToggle }
            )
        } else {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Spacer(minLength: 0)
                viewModeToggle
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
        }
    }

    private var viewModeToggle: some View {
        ExploreViewModeToggle(selection: $viewMode)
    }

    private var tripPlannerLink: some View {
        NavigationLink {
            TripPlannerView()
        } label: {
            Image(systemName: "calendar")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.Colors.iconPrimary)
        .accessibilityLabel("Trip Planner")
    }
}
