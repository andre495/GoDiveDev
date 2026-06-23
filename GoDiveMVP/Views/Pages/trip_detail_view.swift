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
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @Query(sort: \DiveBuddy.displayName) private var rosterBuddies: [DiveBuddy]

    @State private var navigationTarget: TripDetailNavigationTarget?
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor = DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor = DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()
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

    private var homeLayoutSeamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
    }

    private var homeAlignedStatsPanelContentHeight: CGFloat {
        homeLayoutSeamInputs.statsPanelContentHeight
    }

    private var linkedDiveActivities: [DiveActivity] {
        guard let trip else { return [] }
        return DiveTripPresentation.linkedDiveActivities(for: trip)
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
        .task(id: tripDetailContentToken) {
            rebuildTripDetailContent()
            await Task.yield()
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
                guard height > 0, height != headerClearance else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    headerClearance = height
                }
            }
        }
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
    private func tripDetailContent(trip: DiveTrip) -> some View {
        let showsTripStats = DiveTripActivityLinking.hasStarted(trip: trip)
        let mapPins = contentSnapshot.mapPins
        let mediaPhotos = contentSnapshot.mediaPhotos
        let showsHero = !mapPins.isEmpty || !mediaPhotos.isEmpty
        let showsHeroModeToggle = !mapPins.isEmpty

        GeometryReader { proxy in
            let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
            let safeTop = max(rawSafeTop, layoutSafeAreaTopFloor)
            let geometryHeight = max(proxy.size.height, 1)
            let layoutHeight = HomeOverviewLayout.pushedPageLayoutHeight(
                from: geometryHeight,
                transitionViewportFloor: layoutViewportHeightFloor
            )
            let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            )
            let heroTopSafeAreaInset = HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                rawGeometrySafeTop: proxy.safeAreaInsets.top,
                transitionSafeTopFloor: layoutSafeAreaTopFloor
            )
            let mapHeroHeight = TripDetailMapPresentation.mapHeroHeight(
                viewportHeight: geometryHeight,
                screenWidth: proxy.size.width,
                topSafeAreaInset: heroTopSafeAreaInset,
                statsPanelContentHeight: homeAlignedStatsPanelContentHeight,
                showsBuddyLeaderboard: homeLayoutSeamInputs.showsBuddyLeaderboard,
                transitionViewportFloor: layoutViewportHeightFloor
            )
            let heroFitLayout = TripDetailMapFitLayout(
                mapHeight: mapHeroHeight,
                topObstructionHeight: topInset
            )
            let bottomScrollInset = HomeOverviewLayout.pushedPageScrollBottomInset(
                safeAreaBottom: proxy.safeAreaInsets.bottom
            )
            let headerScrollClearance = max(
                0,
                topInset - HomeLifetimeStatsLayout.panelTopContentPadding
            )
            let layoutSnapshot = PageLayoutGeometryProbe.pushed(
                pageKind: .tripDetail,
                screenWidth: proxy.size.width,
                geometryHeight: geometryHeight,
                safeAreaTop: safeTop,
                safeAreaBottom: proxy.safeAreaInsets.bottom,
                layoutStackHeight: layoutHeight,
                heroHeight: mapHeroHeight,
                statsPanelContentHeight: homeAlignedStatsPanelContentHeight,
                scrollBottomInset: bottomScrollInset,
                showsHeroOverlap: showsHero
            )

            ZStack(alignment: .top) {
                VStack(spacing: showsHero ? -HomeLifetimeStatsLayout.panelOverlap : 0) {
                    if showsHero {
                        PushedHeroBand(
                            height: mapHeroHeight,
                            topSafeAreaInset: heroTopSafeAreaInset
                        ) {
                            if mapPins.isEmpty {
                                PushedDetailHeroHeaderView(
                                    media: displayHeroTripMedia,
                                    mapPins: [],
                                    mapFitLayout: heroFitLayout,
                                    height: mapHeroHeight,
                                    shouldAutoPlaySelectedVideo: TripDetailPresentation.shouldAutoPlaySelectedVideo(
                                        for: displayHeroTripMedia
                                    ),
                                    style: .trip,
                                    onSiteSelected: openDiveSiteFromMap,
                                    selectedMode: .constant(.media)
                                )
                            } else if mediaPhotos.isEmpty {
                                Group {
                                    if showsDeferredMap {
                                        TripDetailMapView(
                                            pins: mapPins,
                                            fitLayout: heroFitLayout
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
                                    } else {
                                        AppTheme.Colors.surfaceMuted.opacity(0.35)
                                    }
                                }
                                .accessibilityIdentifier("TripDetail.MapBand")
                            } else {
                                PushedDetailHeroHeaderView(
                                    media: displayHeroTripMedia,
                                    mapPins: mapPins,
                                    mapFitLayout: heroFitLayout,
                                    height: mapHeroHeight,
                                    isMapContentReady: showsDeferredMap,
                                    shouldAutoPlaySelectedVideo: TripDetailPresentation.shouldAutoPlaySelectedVideo(
                                        for: displayHeroTripMedia
                                    ),
                                    style: .trip,
                                    onSiteSelected: openDiveSiteFromMap,
                                    selectedMode: $tripHeroMode
                                )
                                .onAppear {
                                    if showsDeferredMap {
                                        TripDetailMapNavigationDebug.tripMapAppeared(
                                            pinCount: mapPins.count,
                                            openablePinCount: mapPins.filter { $0.siteID != nil }.count,
                                            hasOpenCatalogDiveSiteDetail: openCatalogDiveSiteDetail != nil,
                                            tripID: trip.id
                                        )
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier(
                            mediaPhotos.isEmpty ? "TripDetail.MapBand" : "TripDetail.HeroBand"
                        )
                    }

                    HomeLifetimeStatsPanel(
                        overlapsMedia: showsHero,
                        bottomSafeAreaInset: 0
                    ) {
                        tripDetailPanelContent(
                            trip: trip,
                            showsTripStats: showsTripStats,
                            mapPins: mapPins,
                            headerScrollClearance: showsHero ? 0 : headerScrollClearance,
                            bottomScrollInset: bottomScrollInset
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("TripDetail.ContentPanel")
                    .zIndex(1)
                    .ignoresSafeArea(edges: .bottom)
                }
                .overlay(alignment: .top) {
                    if showsHeroModeToggle {
                        PushedDetailHeroModeToggle(
                            selectedMode: $tripHeroMode,
                            accessibilityIdentifierPrefix: "TripDetail.Hero.ModeToggle"
                        )
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.bottom, TripDetailPresentation.heroModeToggleBottomPadding)
                        .frame(width: proxy.size.width, height: mapHeroHeight, alignment: .bottomTrailing)
                    }
                }

                tripDetailBackChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    showsMapScrim: showsHero
                )
            }
            .frame(width: proxy.size.width, height: layoutHeight)
            .ignoresSafeArea(edges: .bottom)
            .pageLayoutGeometryOverlay(layoutSnapshot)
            .animation(nil, value: mapHeroHeight)
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                guard height > 0, height != headerClearance else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    headerClearance = height
                }
            }
            .onChange(of: rawSafeTop, initial: true) { _, resolvedTop in
                guard resolvedTop > layoutSafeAreaTopFloor else { return }
                layoutSafeAreaTopFloor = resolvedTop
            }
            .onChange(of: geometryHeight, initial: true) { _, height in
                let subtractedViewport = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: height)
                let transitionViewport = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(
                    from: height
                )
                guard subtractedViewport < transitionViewport else { return }
                guard transitionViewport > layoutViewportHeightFloor else { return }
                layoutViewportHeightFloor = transitionViewport
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

            let featuredToggleAction: (() -> Void)? = contentSnapshot.mediaPhotos.isEmpty
                ? nil
                : { toggleFeaturedTripMedia() }

            TripDetailContentPager(
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
