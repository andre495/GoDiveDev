import SwiftUI

/// Read-only planned **`DiveSite`** list from trip overview — same row chrome as **Explore** list.
struct TripPlannedSitesListView: View {
    let plannedSites: [DiveSite]
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @State private var searchQuery = ""

    init(
        plannedSites: [DiveSite],
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void = { _ in }
    ) {
        self.plannedSites = plannedSites
        self.ownerProfileID = ownerProfileID
        self.onOpenDive = onOpenDive
    }

    private var sortedSites: [DiveSite] {
        plannedSites.sorted {
            $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
        }
    }

    private var filteredSites: [DiveSite] {
        ExploreDiveSiteListSearch.filtering(sortedSites, query: searchQuery)
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: filteredSites, trailingStyle: .plannedTrip)
    }

    private var isFilteringSites: Bool {
        ExploreDiveSiteListSearch.isFiltering(query: searchQuery)
    }

    var body: some View {
        AppPage(
            title: DiveTripPresentation.plannedSitesSectionTitle,
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            showsWaterBubbleBackground: true
        ) {
            plannedSitesListContent
        }
        .searchable(text: $searchQuery, prompt: "Search dive sites")
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("TripPlannedSites.Root")
    }

    @ViewBuilder
    private var plannedSitesListContent: some View {
        if sortedSites.isEmpty {
            AppScrollUnderHeaderEmptyState {
                ContentUnavailableView(
                    "No planned sites",
                    systemImage: "mappin.and.ellipse",
                    description: Text("Add dive sites when editing this trip.")
                )
            }
        } else if siteListRows.isEmpty, isFilteringSites {
            AppScrollUnderHeaderEmptyState {
                CatalogSearchEmptyState(
                    title: "No matching dive sites",
                    message: "Try a different site name or place."
                )
            }
        } else {
            AppScrollUnderHeaderList(listAccessibilityIdentifier: "TripPlannedSites.List") {
                ForEach(siteListRows) { row in
                    NavigationLink {
                        ExploreDiveSiteDetailHost(
                            siteID: row.id,
                            ownerProfileID: ownerProfileID,
                            onOpenDive: onOpenDive
                        )
                    } label: {
                        ExploreDiveSiteRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("TripPlannedSites.Row.\(row.id.uuidString)")
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
