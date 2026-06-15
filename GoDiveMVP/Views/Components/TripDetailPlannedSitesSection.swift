import SwiftUI

/// Planned dive sites on trip overview — Explore-style rows.
struct TripDetailPlannedSitesSection: View {
    let plannedSites: [DiveSite]
    let ownerProfileID: UUID?

    private var sortedSites: [DiveSite] {
        plannedSites.sorted {
            $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
        }
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: sortedSites)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(DiveTripPresentation.plannedSitesPageSubtitle(siteCount: sortedSites.count))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.md)
                .accessibilityIdentifier(
                    sortedSites.isEmpty ? "TripDetail.PlannedSites.Empty" : "TripDetail.PlannedSites.Subtitle"
                )

            if sortedSites.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(siteListRows) { row in
                        if let site = sortedSites.first(where: { $0.id == row.id }) {
                            NavigationLink {
                                ExploreDiveSiteDetailView(
                                    site: site,
                                    ownerProfileID: ownerProfileID
                                )
                                .hidesBottomTabBarWhenPushed()
                            } label: {
                                ExploreDiveSiteRow(data: row)
                                    .equatable()
                            }
                            .buttonStyle(.plain)
                            .navigationLinkIndicatorVisibility(.hidden)
                            .accessibilityIdentifier("TripDetail.PlannedSites.\(row.id.uuidString)")
                        }
                    }
                }
                .accessibilityIdentifier("TripDetail.PlannedSites.List")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.PlannedSitesSection")
    }
}
