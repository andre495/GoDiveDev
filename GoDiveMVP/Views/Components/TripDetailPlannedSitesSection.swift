import SwiftData
import SwiftUI

/// Planned dive sites on trip overview — Explore-style rows with **+** to edit saved sites.
struct TripDetailPlannedSitesSection: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: DiveTrip
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @Query(sort: \DiveSite.siteName) private var diveSiteCatalog: [DiveSite]

    @State private var showsSitePicker = false
    @State private var selectedSiteIDs: Set<UUID> = []

    private var sortedSites: [DiveSite] {
        trip.plannedSites.sorted {
            $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
        }
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreDiveSiteListDisplay.rowData(for: sortedSites, trailingStyle: .plannedTrip)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(DiveTripPresentation.plannedSitesPageSubtitle(siteCount: sortedSites.count))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(
                        sortedSites.isEmpty ? "TripDetail.PlannedSites.Empty" : "TripDetail.PlannedSites.Subtitle"
                    )

                Button {
                    selectedSiteIDs = Set(trip.plannedSites.map(\.id))
                    showsSitePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DiveTripPresentation.addPlannedSiteAccessibilityLabel)
                .accessibilityIdentifier("TripDetail.PlannedSites.Add")
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            if sortedSites.isEmpty {
                Text(DiveTripPresentation.tripPlannedSitesEmptyMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.md)
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(siteListRows) { row in
                        if let site = sortedSites.first(where: { $0.id == row.id }) {
                            NavigationLink {
                                ExploreDiveSiteDetailView(
                                    site: site,
                                    ownerProfileID: ownerProfileID,
                                    onOpenDive: onOpenDive
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
                .padding(.horizontal, AppTheme.Spacing.md)
                .accessibilityIdentifier("TripDetail.PlannedSites.List")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.PlannedSitesSection")
        .sheet(isPresented: $showsSitePicker, onDismiss: applySelectedPlannedSites) {
            TripPlannedSitePickerSheet(
                selectedSiteIDs: $selectedSiteIDs,
                sites: diveSiteCatalog
            )
        }
    }

    private func applySelectedPlannedSites() {
        let selected = diveSiteCatalog
            .filter { selectedSiteIDs.contains($0.id) }
            .sorted {
                $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
            }
        trip.plannedSites = selected
        trip.updatedAt = .now
        try? modelContext.save()
    }
}
