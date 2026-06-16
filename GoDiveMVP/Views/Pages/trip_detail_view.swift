import SwiftData
import SwiftUI

/// Read-only summary for a saved **`DiveTrip`**.
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.openCatalogDiveSiteDetail) private var openCatalogDiveSiteDetail
    @Environment(AccountSession.self) private var accountSession

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Query private var trips: [DiveTrip]
    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query private var allSightings: [SightingInstance]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @Query(sort: \DiveSite.siteName) private var diveSiteCatalog: [DiveSite]
    @Query(sort: \DiveBuddy.displayName) private var rosterBuddies: [DiveBuddy]

    @State private var navigationTarget: TripDetailNavigationTarget?
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var showsEditSheet = false
    @State private var showsShareSheet = false
    @State private var shareImageURL: URL?
    @State private var isPreparingShare = false

    let tripID: UUID
    var initialContentPage: TripDetailContentPage?
    var initialSelectedMediaID: UUID?

    init(
        tripID: UUID,
        initialContentPage: TripDetailContentPage? = nil,
        initialSelectedMediaID: UUID? = nil
    ) {
        self.tripID = tripID
        self.initialContentPage = initialContentPage
        self.initialSelectedMediaID = initialSelectedMediaID
        _trips = Query(filter: #Predicate<DiveTrip> { $0.id == tripID })
    }

    private var trip: DiveTrip? {
        trips.first
    }

    private var aggregate: DiveTripAggregate {
        guard let trip else { return .empty }
        return DiveTripAggregateBuilder.build(
            trip: trip,
            marineLifeCatalog: marineLifeCatalog,
            allSightings: allSightings
        )
    }

    private var ownedDiveActivities: [DiveActivity] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerID }
    }

    private var linkedDiveActivities: [DiveActivity] {
        guard let trip else { return [] }
        return DiveTripPresentation.linkedDiveActivities(for: trip)
    }

    private var linkedDiveRows: [DiveLogbookRowDisplayData] {
        guard let trip else { return [] }
        return DiveTripPresentation.linkedDiveRowDisplayData(
            trip: trip,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingActivities: ownedDiveActivities
        )
    }

    private var tripLinkedMediaItems: [TripDetailLinkedMediaItem] {
        TripDetailMediaPresentation.linkedMediaItems(from: linkedDiveActivities)
    }

    private var tripMediaPhotos: [DiveMediaPhoto] {
        TripDetailMediaPresentation.mediaPhotos(
            from: linkedDiveActivities,
            itemIDs: tripLinkedMediaItems
        )
    }

    private var tripMediaTimeZoneOffsets: [UUID: Int?] {
        TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: linkedDiveActivities,
            itemIDs: tripLinkedMediaItems
        )
    }

    private var tripMediaSightings: [SightingInstance] {
        let linkedDiveIDs = Set(linkedDiveActivities.map(\.id))
        return allSightings.filter { sighting in
            guard let diveID = sighting.diveActivityID else { return false }
            return linkedDiveIDs.contains(diveID)
        }
    }

    private var tripMarineLifeCarouselItems: [TripDetailMarineLifeCarouselItem] {
        TripDetailMarineLifePresentation.carouselItems(
            from: aggregate.marineLife,
            catalog: marineLifeCatalog,
            unitSystem: diveDisplayUnitSystem
        )
    }

    private var rosterBuddiesByID: [UUID: DiveBuddy] {
        guard let ownerProfileID = accountSession.currentProfile?.id else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: rosterBuddies
                .filter { $0.ownerProfileID == ownerProfileID }
                .map { ($0.id, $0) }
        )
    }

    private var autoLinkSyncToken: String {
        guard let trip else { return tripID.uuidString }
        let divePart = ownedDiveActivities.map(\.id.uuidString).joined(separator: ",")
        return "\(trip.id.uuidString)-\(trip.activityLinks.count)|\(divePart)"
    }

    var body: some View {
        AppHeaderlessPage {
            if let trip {
                tripDetailContent(trip: trip)
            } else {
                missingTripContent
            }
        }
        .navigationDestination(item: $navigationTarget) { target in
            tripNavigationDestination(for: target)
        }
        .toolbar(.hidden, for: .navigationBar)
        .hidesBottomTabBarWhenPushed()
        .task(id: autoLinkSyncToken) {
            syncTripActivityLinks()
        }
        .sheet(isPresented: $showsEditSheet) {
            if let trip {
                TripEditSheetView(trip: trip) {
                    showsEditSheet = false
                } onDeleted: {
                    showsEditSheet = false
                    dismiss()
                }
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showsShareSheet, onDismiss: cleanupShareFile) {
            if let shareImageURL {
                AppShareSheet(activityItems: [shareImageURL], onComplete: cleanupShareFile)
            }
        }
        #endif
        .accessibilityIdentifier("TripDetail.Root")
    }

    private var missingTripContent: some View {
        GeometryReader { proxy in
            let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
            let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            )
            let headerScrollClearance = max(
                0,
                topInset - HomeLifetimeStatsLayout.panelTopContentPadding
            )

            ZStack(alignment: .top) {
                HomeLifetimeStatsPanel(
                    overlapsMedia: false,
                    bottomSafeAreaInset: proxy.safeAreaInsets.bottom
                ) {
                    Text("This trip is no longer available.")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, headerScrollClearance)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                tripDetailBackChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    showsMapScrim: false
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
        }
    }

    private func syncTripActivityLinks() {
        guard let trip else { return }
        let linked = DiveTripActivityLinking.applyAutoLink(
            to: trip,
            activities: ownedDiveActivities,
            modelContext: modelContext
        )
        if linked > 0 {
            try? modelContext.save()
            DiveTripLogbookSync.notifyGroupingDidChange()
        }
    }

    @ViewBuilder
    private func tripDetailContent(trip: DiveTrip) -> some View {
        let showsTripStats = DiveTripActivityLinking.hasStarted(trip: trip)
        let mapPins = TripDetailMapPresentation.pins(
            plannedSites: trip.plannedSites,
            linkedActivities: linkedDiveActivities,
            catalogSites: diveSiteCatalog
        )

        GeometryReader { proxy in
            let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
            let layoutHeight = max(proxy.size.height, 1)
            let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            )
            let mapHeroHeight = TripDetailMapPresentation.mapHeroHeight(
                viewportHeight: layoutHeight,
                screenWidth: proxy.size.width,
                topSafeAreaInset: safeTop
            )
            let showsMap = !mapPins.isEmpty
            let bottomInset = proxy.safeAreaInsets.bottom
            let headerScrollClearance = max(
                0,
                topInset - HomeLifetimeStatsLayout.panelTopContentPadding
            )

            ZStack(alignment: .top) {
                VStack(spacing: showsMap ? -HomeLifetimeStatsLayout.panelOverlap : 0) {
                    if showsMap {
                        TripDetailMapView(
                            pins: mapPins,
                            fitLayout: TripDetailMapFitLayout(
                                mapHeight: mapHeroHeight,
                                topObstructionHeight: topInset
                            )
                        ) { siteID in
                            openDiveSiteFromMap(siteID)
                        }
                            .onAppear {
                                TripDetailMapNavigationDebug.tripMapAppeared(
                                    pinCount: mapPins.count,
                                    openablePinCount: mapPins.filter { $0.siteID != nil }.count,
                                    hasOpenCatalogDiveSiteDetail: openCatalogDiveSiteDetail != nil,
                                    tripID: trip.id
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: mapHeroHeight)
                            .padding(.top, -safeTop)
                            .ignoresSafeArea(edges: [.top, .horizontal])
                            .accessibilityIdentifier("TripDetail.MapBand")
                    }

                    HomeLifetimeStatsPanel(
                        overlapsMedia: showsMap,
                        bottomSafeAreaInset: 0
                    ) {
                        tripDetailPanelContent(
                            trip: trip,
                            showsTripStats: showsTripStats,
                            mapPins: mapPins,
                            headerScrollClearance: showsMap ? 0 : headerScrollClearance,
                            bottomScrollInset: bottomInset
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("TripDetail.ContentPanel")
                    .zIndex(1)
                }

                tripDetailBackChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    showsMapScrim: showsMap
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
        }
        .ignoresSafeArea(edges: [.horizontal])
        .accessibilityIdentifier("TripDetail.Content")
    }

    private func tripDetailPanelContent(
        trip: DiveTrip,
        showsTripStats: Bool,
        mapPins: [TripDetailMapPin],
        headerScrollClearance: CGFloat,
        bottomScrollInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if headerScrollClearance > 0 {
                Color.clear
                    .frame(height: headerScrollClearance)
                    .accessibilityHidden(true)
            }

            tripTitleBlock(trip: trip, mapPins: mapPins)

            TripDetailContentPager(
                trip: trip,
                hasStarted: showsTripStats,
                statTiles: DiveTripStatsPresentation.highlightTiles(
                    from: aggregate,
                    unitSystem: diveDisplayUnitSystem
                ),
                aggregate: aggregate,
                linkedDiveRows: linkedDiveRows,
                marineLifeItems: tripMarineLifeCarouselItems,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: diveDisplayUnitSystem,
                ownerProfileID: accountSession.currentProfile?.id,
                ownerProfile: accountSession.currentProfile,
                rosterBuddiesByID: rosterBuddiesByID,
                mediaItems: tripMediaPhotos,
                mediaTimeZoneOffsets: tripMediaTimeZoneOffsets,
                linkedMediaItems: tripLinkedMediaItems,
                mediaSightings: tripMediaSightings,
                bottomScrollInset: bottomScrollInset,
                initialContentPage: initialContentPage,
                initialSelectedMediaID: initialSelectedMediaID,
                onOpenDive: { pushTripNavigation(.linkedDive($0)) },
                onOpenInDive: { diveID, mediaID in
                    pushTripNavigation(.diveMedia(diveID: diveID, mediaID: mediaID))
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func tripTitleBlock(trip: DiveTrip, mapPins: [TripDetailMapPin]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 0) {
                Text(trip.displayTitle)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("TripDetail.Title")

                Button {
                    showsEditSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.Colors.iconPrimary)
                .accessibilityLabel(TripPlannerPresentation.editTripToolbarAccessibilityLabel)
                .accessibilityIdentifier("TripDetail.Edit")

                Button {
                    prepareTripShare(trip: trip, mapPins: mapPins)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(AppTheme.Colors.iconPrimary)
                .disabled(isPreparingShare)
                .accessibilityLabel(DiveTripPresentation.shareTripButtonTitle)
                .accessibilityIdentifier("TripDetail.Share")
            }

            Text(DiveTripPresentation.formattedDateRange(start: trip.startDate, end: trip.endDate))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    #if canImport(UIKit)
    private func prepareTripShare(trip: DiveTrip, mapPins: [TripDetailMapPin]) {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        let hasStarted = DiveTripActivityLinking.hasStarted(trip: trip)
        let members = TripShareCardPresentation.members(
            hasStarted: hasStarted,
            owner: accountSession.currentProfile,
            ownerLinkedDiveCount: aggregate.diveCount,
            plannedBuddies: DiveTripPlannedBuddyLinking.plannedBuddies(for: trip),
            taggedBuddies: aggregate.buddies,
            rosterBuddiesByID: rosterBuddiesByID
        )
        let uniqueMarineLifeCount = aggregate.marineLife.count
        let title = trip.displayTitle
        let dateRange = DiveTripPresentation.formattedDateRange(
            start: trip.startDate,
            end: trip.endDate
        )
        let pins = mapPins
        Task { @MainActor in
            shareImageURL = await TripShareCardRenderer.renderPNG(
                tripTitle: title,
                dateRange: dateRange,
                members: members,
                uniqueMarineLifeCount: uniqueMarineLifeCount,
                mapPins: pins
            )
            isPreparingShare = false
            showsShareSheet = shareImageURL != nil
        }
    }

    private func cleanupShareFile() {
        if let shareImageURL {
            try? FileManager.default.removeItem(at: shareImageURL)
        }
        shareImageURL = nil
    }
    #else
    private func prepareTripShare(trip: DiveTrip, mapPins: [TripDetailMapPin]) {}
    #endif

    @ViewBuilder
    private func tripDetailBackChrome(
        safeTop: CGFloat,
        topInset: CGFloat,
        showsMapScrim: Bool
    ) -> some View {
        if showsMapScrim {
            LogbookTopChromeScrim(topObstructionHeight: topInset)
                .padding(.top, -safeTop)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .zIndex(0.5)
        }

        Color.clear
            .frame(height: topInset)
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .zIndex(0.75)

        AppHeader(
            title: "",
            showsBackButton: true,
            showsBrandWordmark: false,
            statusBarSafeAreaTop: safeTop
        )
        .frame(maxWidth: .infinity, alignment: .top)
        .zIndex(1)
    }

    private func pushTripNavigation(_ target: TripDetailNavigationTarget) {
        guard navigationTarget == nil else { return }
        navigationTarget = target
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        TripDetailMapNavigationDebug.openDiveSiteFromMapCalled(siteID: siteID, tripID: trip?.id)

        guard let site = TripDetailDiveSiteNavigation.resolvedSite(
            siteID: siteID,
            plannedSites: trip?.plannedSites ?? [],
            catalogSites: diveSiteCatalog
        ) else {
            TripDetailMapNavigationDebug.siteResolutionFailed(siteID: siteID)
            return
        }

        TripDetailMapNavigationDebug.siteResolutionSucceeded(siteID: siteID, siteName: site.siteName)

        guard let openCatalogDiveSiteDetail else {
            TripDetailMapNavigationDebug.openCatalogDiveSiteDetailMissing(siteID: siteID)
            return
        }

        openCatalogDiveSiteDetail(siteID)
    }

    @ViewBuilder
    private func tripNavigationDestination(for target: TripDetailNavigationTarget) -> some View {
        switch target {
        case .linkedDive(let diveID):
            if let activity = linkedDiveActivities.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity)
            } else {
                tripUnavailableDestination(
                    title: "Dive unavailable",
                    message: "This dive is no longer linked to the trip."
                )
            }
        case .diveMedia(let diveID, let mediaID):
            if let activity = linkedDiveActivities.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                tripUnavailableDestination(
                    title: "Dive unavailable",
                    message: "This dive is no longer linked to the trip."
                )
            }
        }
    }

    private func tripUnavailableDestination(title: String, message: String) -> some View {
        AppPage(title: title, showsBackButton: true, showsBrandWordmark: false) {
            Text(message)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.lg)
        }
        .hidesBottomTabBarWhenPushed()
    }
}
