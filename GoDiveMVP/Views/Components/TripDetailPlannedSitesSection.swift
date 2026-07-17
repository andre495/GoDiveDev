import SwiftData
import SwiftUI

/// Planned dive sites on trip overview — Explore-style rows with **+** to edit saved sites.
struct TripDetailPlannedSitesSection: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: DiveTrip
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @State private var diveSiteCatalog: [DiveSite] = []
    @State private var userDiveSites: [UserDiveSite] = []

    @State private var showsSitePicker = false
    @State private var selectedSiteIDs: Set<UUID> = []

    private var sortedSites: [DiveLinkedSiteResolver.ResolvedSite] {
        let plannedIDs = trip.plannedSiteIDs
        let userByID = Dictionary(uniqueKeysWithValues: userDiveSites.map { ($0.id, $0) })
        let catalogByID = Dictionary(uniqueKeysWithValues: diveSiteCatalog.map { ($0.id, $0) })
        return plannedIDs.compactMap {
            DiveLinkedSiteResolver.resolve(id: $0, userSitesByID: userByID, catalogSitesByID: catalogByID)
        }
        .sorted {
            $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
        }
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        let userByID = Dictionary(uniqueKeysWithValues: userDiveSites.map { ($0.id, $0) })
        let catalogByID = Dictionary(uniqueKeysWithValues: diveSiteCatalog.map { ($0.id, $0) })
        return sortedSites.map { resolved in
            if let user = userByID[resolved.id] {
                return DiveSitePresentation.listRecord(for: user, trailingStyle: .plannedTrip)
            }
            if let catalog = catalogByID[resolved.id] {
                return DiveSitePresentation.listRecord(for: catalog, trailingStyle: .plannedTrip)
            }
            return DiveSitePresentation.listRecord(
                for: UserDiveSite(
                    id: resolved.id,
                    siteName: resolved.siteName,
                    country: resolved.country,
                    region: resolved.region,
                    bodyOfWater: resolved.bodyOfWater,
                    latCoords: resolved.latCoords,
                    longCoords: resolved.longCoords
                ),
                trailingStyle: .plannedTrip
            )
        }
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
                    selectedSiteIDs = Set(trip.plannedSiteIDs)
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

            if sortedSites.isEmpty {
                Text(DiveTripPresentation.tripPlannedSitesEmptyMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(siteListRows) { row in
                        NavigationLink {
                            ExploreDiveSiteDetailHost(
                                siteID: row.id,
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
                .accessibilityIdentifier("TripDetail.PlannedSites.List")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.PlannedSitesSection")
        .task {
            diveSiteCatalog = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
            userDiveSites = (try? modelContext.fetch(
                FetchDescriptor<UserDiveSite>(sortBy: [SortDescriptor(\.siteName)])
            )) ?? []
        }
        .sheet(isPresented: $showsSitePicker) {
            TripPlannedSitePickerSheet(
                selectedSiteIDs: $selectedSiteIDs,
                sites: diveSiteCatalog,
                onCancel: {
                    selectedSiteIDs = Set(trip.plannedSiteIDs)
                },
                onDone: applySelectedPlannedSites
            )
        }
    }

    private func applySelectedPlannedSites() {
        let selected = diveSiteCatalog
            .filter { selectedSiteIDs.contains($0.id) }
            .sorted {
                $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending
            }
        trip.plannedSiteIDs = selected.map(\.id)
        trip.updatedAt = .now
        try? modelContext.save()
    }
}
