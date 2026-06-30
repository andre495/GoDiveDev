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
    @Query private var ownerTrips: [DiveTrip]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @Query(sort: \DiveBuddy.displayName) private var rosterBuddies: [DiveBuddy]

    @State private var navigationTarget: TripDetailNavigationTarget?
    @State private var contentSnapshot = TripDetailContentSnapshot.empty
    @State private var showsDeferredMap = false
    @State private var tripHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var heroTripMediaID: UUID?
    @State private var gallerySelectedMediaID: UUID?
    @State private var showsEditSheet = false
    @State private var showsShareSheet = false
    @State private var shareImageURL: URL?
    @State private var isPreparingShare = false

    let tripID: UUID
    var initialContentPage: TripDetailContentPage?
    var initialSelectedMediaID: UUID?

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(
        tripID: UUID,
        initialContentPage: TripDetailContentPage? = nil,
        initialSelectedMediaID: UUID? = nil
    ) {
        self.tripID = tripID
        self.initialContentPage = initialContentPage
        self.initialSelectedMediaID = initialSelectedMediaID
        _trips = Query(filter: #Predicate<DiveTrip> { $0.id == tripID })
        let ownerID = AccountSession.shared.currentProfile?.id ?? Self.noOwnerQueryToken
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == ownerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.id, order: .forward),
            ]
        )
        _diveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerID },
            sort: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        _rosterBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == ownerID },
            sort: [SortDescriptor(\.displayName)]
        )
    }

    private var trip: DiveTrip? {
        trips.first
    }

    private var ownedDiveActivities: [DiveActivity] {
        guard accountSession.currentProfile != nil else { return [] }
        return diveActivities
    }

    private var linkedDiveActivities: [DiveActivity] {
        guard let trip else { return [] }
        return DiveTripPresentation.linkedDiveActivities(for: trip)
    }

    private var ownedTrips: [DiveTrip] {
        guard accountSession.currentProfile != nil else { return [] }
        return ownerTrips
    }

    private func tripLogbookAccentColor(for trip: DiveTrip) -> Color {
        LogbookTripGroupAccentPresentation.accentColor(
            for: trip.id,
            ownerActivities: ownedDiveActivities,
            ownerTrips: ownedTrips,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives
        )
    }

    private var tripDetailContentToken: String {
        guard let trip else { return tripID.uuidString }
        return [
            trip.id.uuidString,
            "\(trip.activityLinks.count)",
            "\(ownedDiveActivities.count)",
            trip.featuredTripMediaPhotoID?.uuidString ?? "",
            diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives ? "1" : "0",
        ].joined(separator: "|")
    }

    private var autoLinkSyncToken: String {
        tripDetailContentToken
    }

    var body: some View {
        Group {
            if let trip {
                tripDetailBlueSheet(trip: trip)
            } else {
                missingTripBlueSheet
            }
        }
        .navigationDestination(item: $navigationTarget) { target in
            tripNavigationDestination(for: target)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: tripDetailContentToken) {
            await Task.yield()
            let signpostID = AppPerformanceSignpost.begin(.tripDetailContentRebuild)
            rebuildTripDetailContent()
            AppPerformanceSignpost.end(.tripDetailContentRebuild, signpostID: signpostID)
            showsDeferredMap = true
            await enrichTripDetailMarineLife()
            await warmTripHeroHeaderMediaPreviewIfNeeded()
        }
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.tripDetail(tripID))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.tripDetail(tripID))
        }
        .task(id: autoLinkSyncToken) {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(300))
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
    }

    private var missingTripBlueSheet: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "TripDetail.Root",
                showsHero: false
            ),
            hero: { _ in EmptyView() },
            heroOverlay: { _ in EmptyView() },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                Text("This trip is no longer available.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .top)
            },
            panelContent: { _, _ in
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    isEditEnabled: false,
                    onEdit: {},
                    editAccessibilityIdentifier: "TripDetail.Edit"
                )
            }
        )
    }

    private func rebuildTripDetailContent() {
        guard let trip else {
            contentSnapshot = .empty
            heroTripMediaID = nil
            return
        }
        contentSnapshot = TripDetailContentSnapshotBuilder.buildLight(
            trip: trip,
            ownedDiveActivities: ownedDiveActivities,
            rosterBuddies: rosterBuddies,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives
        )
        heroTripMediaID = TripDetailPresentation.initialHeroMediaPhotoID(
            for: trip,
            photos: contentSnapshot.mediaPhotos
        )
        if contentSnapshot.mediaPhotos.isEmpty, !contentSnapshot.mapPins.isEmpty {
            tripHeroMode = .map
        }
    }

    private var displayHeroTripMedia: DiveMediaPhoto? {
        guard let heroTripMediaID,
              let media = contentSnapshot.mediaPhotos.first(where: { $0.id == heroTripMediaID })
        else { return nil }
        return media
    }

    private func toggleFeaturedTripMedia() {
        guard let trip,
              let selectedID = gallerySelectedMediaID,
              let selectedMedia = contentSnapshot.mediaPhotos.first(where: { $0.id == selectedID })
        else { return }

        let nextFeaturedID = TripDetailMediaPresentation.toggledFeaturedMediaPhotoID(
            mediaID: selectedMedia.id,
            explicitFeaturedID: trip.featuredTripMediaPhotoID
        )
        try? DiveTripFeaturedMediaStorage.setFeaturedTripMedia(
            nextFeaturedID,
            on: trip,
            modelContext: modelContext
        )

        if let nextFeaturedID {
            heroTripMediaID = nextFeaturedID
        } else {
            heroTripMediaID = TripHeroMediaSession.pickNewRandomHeroMediaID(
                tripID: trip.id,
                in: contentSnapshot.mediaPhotos
            )
        }
    }

    private func warmTripHeroHeaderMediaPreviewIfNeeded() async {
        guard let hero = displayHeroTripMedia else { return }
        await DiveMediaPreviewStorage.ensureStoredPreviews(for: [hero], modelContext: modelContext)
    }

    private func enrichTripDetailMarineLife() async {
        guard let trip else { return }
        let enriched = TripDetailContentSnapshotBuilder.enrichMarineLife(
            snapshot: contentSnapshot,
            trip: trip,
            unitSystem: diveDisplayUnitSystem,
            modelContext: modelContext
        )
        contentSnapshot = enriched
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
    private func tripDetailBlueSheet(trip: DiveTrip) -> some View {
        let showsTripStats = DiveTripActivityLinking.hasStarted(trip: trip)
        let mapPins = contentSnapshot.mapPins
        let showsHeroModeToggle = !mapPins.isEmpty

        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "TripDetail.Content"
            ),
            hero: { context in
                tripHeroBandContent(
                    context: context,
                    trip: trip,
                    mapPins: mapPins
                )
            },
            heroOverlay: { _ in
                if showsHeroModeToggle {
                    PushedDetailHeroModeToggle(
                        selectedMode: $tripHeroMode,
                        accessibilityIdentifierPrefix: "TripDetail.Hero.ModeToggle"
                    )
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, TripDetailPresentation.heroModeToggleBottomPadding)
                }
            },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                tripPinnedSummary(trip: trip)
            },
            panelContent: { bottomScrollInset, _ in
                tripDetailPagerContent(
                    trip: trip,
                    showsTripStats: showsTripStats,
                    bottomScrollInset: bottomScrollInset
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    onEdit: { showsEditSheet = true },
                    editAccessibilityIdentifier: "TripDetail.Edit",
                    editAccessibilityLabel: TripPlannerPresentation.editTripToolbarAccessibilityLabel
                )
            }
        )
        .accessibilityIdentifier("TripDetail.Content")
    }

    @ViewBuilder
    private func tripHeroBandContent(
        context: BlueSheetHeaderPageLayoutContext,
        trip: DiveTrip,
        mapPins: [TripDetailMapPin]
    ) -> some View {
        let heroFitLayout = context.mapFitLayout()
        let heroModeBinding: Binding<PushedDetailHeroHeaderView.Mode> = mapPins.isEmpty
            ? .constant(.media)
            : $tripHeroMode

        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "TripDetail.HeroBand") {
            PushedDetailHeroHeaderView(
                media: displayHeroTripMedia,
                mapPins: showsDeferredMap ? mapPins : [],
                mapFitLayout: heroFitLayout,
                height: context.heroHeight,
                isMapContentReady: showsDeferredMap,
                shouldAutoPlaySelectedVideo: TripDetailPresentation.shouldAutoPlaySelectedVideo(
                    for: displayHeroTripMedia
                ),
                style: .trip,
                onSiteSelected: openDiveSiteFromMap,
                selectedMode: heroModeBinding
            )
            .onAppear {
                guard showsDeferredMap, !mapPins.isEmpty else { return }
                TripDetailMapNavigationDebug.tripMapAppeared(
                    pinCount: mapPins.count,
                    openablePinCount: mapPins.filter { $0.siteID != nil }.count,
                    hasOpenCatalogDiveSiteDetail: openCatalogDiveSiteDetail != nil,
                    tripID: trip.id
                )
            }
        }
    }

    private func tripDetailPagerContent(
        trip: DiveTrip,
        showsTripStats: Bool,
        bottomScrollInset: CGFloat
    ) -> some View {
        let featuredToggleAction: (() -> Void)? = contentSnapshot.mediaPhotos.isEmpty
            ? nil
            : { toggleFeaturedTripMedia() }

        return TripDetailContentPager(
            trip: trip,
            hasStarted: showsTripStats,
            statTiles: DiveTripStatsPresentation.highlightTiles(
                from: contentSnapshot.aggregate,
                unitSystem: diveDisplayUnitSystem
            ),
            aggregate: contentSnapshot.aggregate,
            linkedDiveRows: contentSnapshot.linkedDiveRows,
            marineLifeItems: contentSnapshot.marineLifeItems,
            marineLifeCatalog: contentSnapshot.marineLifeCatalog,
            unitSystem: diveDisplayUnitSystem,
            ownerProfileID: accountSession.currentProfile?.id,
            ownerProfile: accountSession.currentProfile,
            rosterBuddiesByID: contentSnapshot.rosterBuddiesByID,
            mediaItems: contentSnapshot.mediaPhotos,
            mediaTimeZoneOffsets: contentSnapshot.mediaTimeZoneOffsets,
            linkedMediaItems: contentSnapshot.linkedMediaItems,
            mediaSightings: contentSnapshot.mediaSightings,
            featuredTripMediaPhotoID: trip.featuredTripMediaPhotoID,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            onToggleFeaturedTripMedia: featuredToggleAction,
            bottomScrollInset: bottomScrollInset,
            initialContentPage: initialContentPage,
            initialSelectedMediaID: initialSelectedMediaID,
            onOpenDive: { pushTripNavigation(.linkedDive($0)) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func tripPinnedSummary(trip: DiveTrip) -> some View {
        BlueSheetPinnedSummary(
            accent: DiveTripPresentation.formattedDateRange(start: trip.startDate, end: trip.endDate),
            accentColor: tripLogbookAccentColor(for: trip),
            accentFont: BlueSheetPinnedSummaryPresentation.subtitleFont,
            title: trip.displayTitle,
            titleAccessibilityIdentifier: "TripDetail.Title"
        )
    }

    #if canImport(UIKit)
    private func prepareTripShare(trip: DiveTrip, mapPins: [TripDetailMapPin]) {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        let hasStarted = DiveTripActivityLinking.hasStarted(trip: trip)
        let members = TripShareCardPresentation.members(
            hasStarted: hasStarted,
            owner: accountSession.currentProfile,
            ownerLinkedDiveCount: contentSnapshot.aggregate.diveCount,
            plannedBuddies: DiveTripPlannedBuddyLinking.plannedBuddies(for: trip),
            taggedBuddies: contentSnapshot.aggregate.buddies,
            rosterBuddiesByID: contentSnapshot.rosterBuddiesByID
        )
        let uniqueMarineLifeCount = contentSnapshot.aggregate.marineLife.count
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

    private func pushTripNavigation(_ target: TripDetailNavigationTarget) {
        guard navigationTarget == nil else { return }
        navigationTarget = target
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        TripDetailMapNavigationDebug.openDiveSiteFromMapCalled(siteID: siteID, tripID: trip?.id)

        if let site = TripDetailDiveSiteNavigation.resolvedSite(
            siteID: siteID,
            plannedSites: trip?.plannedSites ?? [],
            catalogSites: catalogSitesForNavigation()
        ) {
            TripDetailMapNavigationDebug.siteResolutionSucceeded(siteID: siteID, siteName: site.siteName)
        } else {
            TripDetailMapNavigationDebug.siteResolutionFailed(siteID: siteID)
        }

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

    private func catalogSitesForNavigation() -> [DiveSite] {
        guard let trip else { return [] }
        return TripDetailContentSnapshotBuilder.catalogSitesForNavigation(
            trip: trip,
            linkedActivities: linkedDiveActivities
        )
    }
}
