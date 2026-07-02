import SwiftData
import SwiftUI

/// Lists planned **`DiveTrip`** rows for the signed-in profile; new trips are created from a sheet.
struct TripPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openTripDetail) private var openTripDetail
    @Environment(\.openTripDetailMedia) private var openTripDetailMedia
    @Environment(AccountSession.self) private var accountSession

    @Query(
        sort: [
            SortDescriptor(\DiveTrip.startDate, order: .reverse),
            SortDescriptor(\DiveTrip.createdAt, order: .reverse),
        ]
    )
    private var allTrips: [DiveTrip]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]

    @State private var showsAddTripSheet = false

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownedTrips: [DiveTrip] {
        guard let ownerID = ownerProfileID else { return [] }
        return allTrips.filter { $0.ownerProfileID == ownerID }
    }

    private var tripListSections: [TripPlannerListSection] {
        TripPlannerPresentation.listSections(from: ownedTrips)
    }

    private var ownedDiveActivities: [DiveActivity] {
        guard let ownerID = ownerProfileID else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerID }
    }

    private var autoLinkSyncToken: String {
        let tripPart = ownedTrips.map { "\($0.id.uuidString)-\($0.activityLinks.count)" }.joined(separator: ",")
        let divePart = ownedDiveActivities.map(\.id.uuidString).joined(separator: ",")
        return "\(tripPart)|\(divePart)"
    }

    var body: some View {
        AppPage(
            title: TripPlannerPresentation.pageTitle,
            showsBackButton: true,
            showsBrandWordmark: false,
            scrollContentUnderHeader: true,
            collapsibleInlineTitleHeader: true,
            trailingContent: {
                addTripToolbarButton
            },
            content: {
                if ownedTrips.isEmpty {
                    AppScrollUnderHeaderEmptyState {
                        emptyTripsState
                    }
                } else {
                    tripsList
                }
            }
        )
        .hidesBottomTabBarWhenPushed()
        .sheet(isPresented: $showsAddTripSheet) {
            TripAddSheetView {
                showsAddTripSheet = false
            }
        }
        .task(id: autoLinkSyncToken) {
            syncStartedTripActivityLinks()
        }
        .accessibilityIdentifier("TripPlanner.Root")
    }

    private func syncStartedTripActivityLinks() {
        guard let ownerProfileID else { return }
        _ = try? DiveTripActivityLinking.applyAutoLinkForOwner(
            ownerProfileID: ownerProfileID,
            trips: ownedTrips,
            activities: ownedDiveActivities,
            modelContext: modelContext
        )
    }

    private var addTripToolbarButton: some View {
        Button {
            showsAddTripSheet = true
        } label: {
            Image(systemName: "plus")
                .appToolbarIconButtonLabel()
        }
        .appStandaloneIconButtonStyle()
        .accessibilityLabel(TripPlannerPresentation.addTripToolbarAccessibilityLabel)
        .accessibilityIdentifier("TripPlanner.AddNew")
    }

    private var emptyTripsState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: TripPlannerPresentation.exploreChromeSystemImage)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(TripPlannerPresentation.emptyStateTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(TripPlannerPresentation.emptyStateMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .accessibilityIdentifier("TripPlanner.EmptyState")
    }

    private func linkedActivities(for trip: DiveTrip) -> [DiveActivity] {
        DiveTripPresentation.linkedDiveActivities(for: trip)
            .filter { activity in
                ownedDiveActivities.contains { $0.id == activity.id }
            }
    }

    private var tripsList: some View {
        AppScrollUnderHeaderList(listAccessibilityIdentifier: "TripPlanner.List") {
            ForEach(tripListSections) { section in
                Section {
                    ForEach(section.trips, id: \.id) { trip in
                        switch section.phase {
                        case .upcoming:
                            upcomingTripBannerRow(trip: trip)
                        case .active, .past:
                            let linkedActivities = linkedActivities(for: trip)
                            let previewMediaPhotoID = TripPlannerPresentation.listRowPreviewMediaPhotoID(
                                phase: section.phase,
                                linkedActivities: linkedActivities
                            )
                            let rowData = TripPlannerPresentation.listRowDisplayData(
                                for: trip,
                                phase: section.phase,
                                previewMediaPhotoID: previewMediaPhotoID
                            )
                            tripListRow(trip: trip, rowData: rowData)
                        }
                    }
                } header: {
                    TripPlannerListSectionHeader(
                        title: TripPlannerPresentation.sectionTitle(for: section.phase)
                    )
                    .accessibilityIdentifier("TripPlanner.Section.\(section.phase.rawValue.capitalized)")
                }
            }
        }
    }

    @ViewBuilder
    private func upcomingTripBannerRow(trip: DiveTrip) -> some View {
        let banner = LogbookUpcomingTripPresentation.bannerData(for: trip)
        let bannerView = LogbookUpcomingTripBannerView(
            data: banner,
            accessibilityIdentifier: "TripPlanner.UpcomingTrip.\(trip.id.uuidString)"
        )

        if let openTripDetail {
            Button {
                openTripDetail(trip.id)
            } label: {
                bannerView
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(upcomingTripBannerRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            NavigationLink {
                TripDetailView(tripID: trip.id)
            } label: {
                bannerView
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(upcomingTripBannerRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var upcomingTripBannerRowInsets: EdgeInsets {
        EdgeInsets(
            top: 0,
            leading: AppScrollUnderHeaderListLayout.horizontalListRowInset,
            bottom: AppTheme.Spacing.sm,
            trailing: AppScrollUnderHeaderListLayout.horizontalListRowInset
        )
    }

    @ViewBuilder
    private func tripListRow(trip: DiveTrip, rowData: TripPlannerListRowDisplayData) -> some View {
        let rowLabel = TripPlannerListRow(
            data: rowData,
            onTapMediaPreview: mediaPreviewAction(
                tripID: trip.id,
                previewMediaPhotoID: rowData.previewMediaPhotoID
            )
        )

        if let openTripDetail {
            Button {
                openTripDetail(trip.id)
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            NavigationLink {
                TripDetailView(tripID: trip.id)
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(AppScrollUnderHeaderListLayout.horizontalRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func mediaPreviewAction(tripID: UUID, previewMediaPhotoID: UUID?) -> (() -> Void)? {
        guard let previewMediaPhotoID else { return nil }
        return {
            let launch = TripDetailTripMediaLaunch(tripID: tripID, mediaID: previewMediaPhotoID)
            if let openTripDetailMedia {
                openTripDetailMedia(launch)
            } else {
                openTripDetail?(tripID)
            }
        }
    }
}

// MARK: - Section header

private struct TripPlannerListSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppTheme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    TripPlannerView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
