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
    @State private var cachedTripAccentColor: Color = AppTheme.Colors.accent
    @State private var lastContentRebuildFingerprint: String?
    @State private var didRunAutoLinkThisVisit = false
    @State private var enrichAndWarmTask: Task<Void, Never>?
    @State private var isHandlingShareInvite = false
    @State private var shareInviteErrorTitle: String?
    @State private var shareInviteErrorMessage: String?
    @State private var buddyActivityRows: [LogbookBuddyFeedPresentation.Row] = []
    @State private var isLoadingBuddyActivities = false
    @State private var didLoadBuddyActivitiesForTripID: UUID?

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

    private var tripDetailContentToken: String {
        guard let trip else { return tripID.uuidString }
        return TripDetailPresentation.deferredContentTaskToken(
            tripID: trip.id,
            activityLinkCount: trip.activityLinks.count,
            plannedSiteCount: trip.plannedSiteIDs.count,
            featuredTripMediaPhotoID: trip.featuredTripMediaPhotoID,
            ownedDiveActivityCount: ownedDiveActivities.count,
            unitSystemRawValue: diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives: automaticallyRenumberDives
        )
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: ActivityDeleteSuccessPresentation.didDeleteNotification
            )
        ) { notification in
            guard let activityID = ActivityDeleteSuccessPresentation.activityID(from: notification) else {
                return
            }
            switch navigationTarget {
            case .linkedDive(let id) where id == activityID:
                navigationTarget = nil
            case .diveMedia(let id, _) where id == activityID:
                navigationTarget = nil
            default:
                break
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: tripDetailContentToken) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            let signpostID = AppPerformanceSignpost.begin(.tripDetailContentRebuild)
            rebuildTripDetailContent()
            AppPerformanceSignpost.end(.tripDetailContentRebuild, signpostID: signpostID)
            showsDeferredMap = true
            enrichAndWarmTask?.cancel()
            enrichAndWarmTask = Task { @MainActor in
                await enrichTripDetailMarineLife()
                guard !Task.isCancelled else { return }
                await warmTripHeroHeaderMediaPreviewIfNeeded()
            }
            await enrichAndWarmTask?.value
        }
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.tripDetail(tripID))
        }
        .onDisappear {
            enrichAndWarmTask?.cancel()
            enrichAndWarmTask = nil
            DiveMediaScopeCache.shared.deactivateScope(.tripDetail(tripID))
        }
        // One auto-link pass per visit — must not share the content token (save bumps links / updatedAt).
        .task(id: tripID) {
            guard !didRunAutoLinkThisVisit else { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            syncTripActivityLinks()
            didRunAutoLinkThisVisit = true
        }
        .task(id: tripID) {
            await loadBuddyActivitiesIfNeeded()
        }
        .task(id: tripID) {
            await reconcileOutgoingTripShareAcceptancesIfNeeded()
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
        .alert(
            shareInviteErrorTitle ?? DiveTripShareInvitePresentation.acceptErrorTitle,
            isPresented: Binding(
                get: { shareInviteErrorMessage != nil },
                set: { if !$0 { shareInviteErrorMessage = nil; shareInviteErrorTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareInviteErrorMessage ?? "")
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
            configuration: TripDetailPresentation.blueSheetPageConfiguration(
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
            lastContentRebuildFingerprint = nil
            return
        }
        let fingerprint = TripDetailPresentation.contentRebuildFingerprint(
            tripID: trip.id,
            activityLinkCount: trip.activityLinks.count,
            plannedSiteCount: trip.plannedSiteIDs.count,
            featuredTripMediaPhotoID: trip.featuredTripMediaPhotoID,
            ownedDiveActivityCount: ownedDiveActivities.count,
            rosterBuddyCount: rosterBuddies.count,
            unitSystemRawValue: diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives: automaticallyRenumberDives
        )
        guard lastContentRebuildFingerprint != fingerprint else { return }

        contentSnapshot = TripDetailContentSnapshotBuilder.buildLight(
            trip: trip,
            ownedDiveActivities: ownedDiveActivities,
            rosterBuddies: rosterBuddies,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives
        )
        // Cache once — body must not rebuild the full logbook display cache for accent color.
        cachedTripAccentColor = LogbookTripGroupAccentPresentation.accentColor(
            for: trip.id,
            ownerActivities: ownedDiveActivities,
            ownerTrips: ownedTrips,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives
        )
        heroTripMediaID = TripDetailPresentation.initialHeroMediaPhotoID(
            for: trip,
            photos: contentSnapshot.mediaPhotos
        )
        let hasMedia = !contentSnapshot.mediaPhotos.isEmpty
        let hasMap = !contentSnapshot.mapPins.isEmpty
        tripHeroMode = PushedDetailHeroModePresentation.resolvedMode(
            hasAssociatedMedia: hasMedia,
            hasMapContent: hasMap
        )
        lastContentRebuildFingerprint = fingerprint
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
        guard !Task.isCancelled else { return }
        let marineLifeCatalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        guard !Task.isCancelled else { return }
        let enriched = TripDetailContentSnapshotBuilder.enrichMarineLife(
            snapshot: contentSnapshot,
            trip: trip,
            unitSystem: diveDisplayUnitSystem,
            marineLifeCatalog: marineLifeCatalog,
            modelContext: modelContext
        )
        guard !Task.isCancelled else { return }
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
        let hasTripMedia = !contentSnapshot.mediaPhotos.isEmpty
        let showsHeroModeToggle = PushedDetailHeroModePresentation.showsModeToggle(
            hasAssociatedMedia: hasTripMedia,
            hasMapContent: !mapPins.isEmpty
        )

        BlueSheetDetailPage(
            configuration: TripDetailPresentation.blueSheetPageConfiguration(
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    tripPinnedSummary(trip: trip)
                    if DiveTripShareLineagePresentation.isPendingInvite(trip) {
                        TripShareInviteCheckpointBanner(
                            sharerDisplayName: sharerDisplayName(for: trip),
                            onAccept: { acceptShareInvite(trip: trip) },
                            onDecline: { declineShareInvite(trip: trip) },
                            isBusy: isHandlingShareInvite
                        )
                    }
                }
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

    private func sharerDisplayName(for trip: DiveTrip) -> String? {
        guard let uid = trip.sharedFromFirebaseUID else { return nil }
        return rosterBuddies.first(where: {
            DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: $0) == uid
        })?.displayName
    }

    private func acceptShareInvite(trip: DiveTrip) {
        guard !isHandlingShareInvite else { return }
        isHandlingShareInvite = true
        Task { @MainActor in
            defer { isHandlingShareInvite = false }
            do {
                try await GoDiveTripShareSync.acceptInvite(
                    for: trip,
                    ownerTrips: ownedTrips,
                    modelContext: modelContext
                )
            } catch let error as GoDiveTripShareSync.AcceptError {
                shareInviteErrorTitle = DiveTripShareInvitePresentation.acceptErrorTitle
                switch error {
                case .dateOverlap(let conflictTitle):
                    shareInviteErrorMessage = DiveTripShareInvitePresentation.acceptOverlapMessage(
                        conflictTitle: conflictTitle
                    )
                case .missingInvite, .firebaseUnavailable:
                    shareInviteErrorMessage = "Try again when you’re online."
                }
            } catch {
                shareInviteErrorTitle = DiveTripShareInvitePresentation.acceptErrorTitle
                shareInviteErrorMessage = "Try again when you’re online."
            }
        }
    }

    private func declineShareInvite(trip: DiveTrip) {
        guard !isHandlingShareInvite else { return }
        isHandlingShareInvite = true
        Task { @MainActor in
            defer { isHandlingShareInvite = false }
            do {
                try await GoDiveTripShareSync.declineInvite(
                    for: trip,
                    modelContext: modelContext
                )
                dismiss()
            } catch {
                shareInviteErrorTitle = DiveTripShareInvitePresentation.declineErrorTitle
                shareInviteErrorMessage = "Try again when you’re online."
            }
        }
    }

    @ViewBuilder
    private func tripHeroBandContent(
        context: BlueSheetHeaderPageLayoutContext,
        trip: DiveTrip,
        mapPins: [TripDetailMapPin]
    ) -> some View {
        let heroFitLayout = context.mapFitLayout()
        let heroModeBinding = PushedDetailHeroModePresentation.heroModeBinding(
            hasAssociatedMedia: !contentSnapshot.mediaPhotos.isEmpty,
            hasMapContent: !mapPins.isEmpty,
            mode: $tripHeroMode
        )

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
            buddyActivityRows: buddyActivityRows,
            isLoadingBuddyActivities: isLoadingBuddyActivities,
            onOpenDive: { pushTripNavigation(.linkedDive($0)) },
            onOpenBuddySharedActivity: { pushTripNavigation(.buddySharedActivity($0)) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @MainActor
    private func loadBuddyActivitiesIfNeeded() async {
        guard let trip else { return }
        guard DiveTripActivityLinking.hasStarted(trip: trip) else {
            buddyActivityRows = []
            isLoadingBuddyActivities = false
            didLoadBuddyActivitiesForTripID = trip.id
            return
        }
        guard didLoadBuddyActivitiesForTripID != trip.id else { return }
        isLoadingBuddyActivities = true
        defer { isLoadingBuddyActivities = false }
        await Task.yield()
        let rows = await TripDetailBuddyActivitiesFetch.loadRows(for: trip)
        guard !Task.isCancelled else { return }
        buddyActivityRows = rows
        didLoadBuddyActivitiesForTripID = trip.id
    }

    @MainActor
    private func reconcileOutgoingTripShareAcceptancesIfNeeded() async {
        guard let trip,
              let owner = accountSession.currentProfile,
              DiveTripShareLineagePresentation.canEditSharedDetails(trip),
              !trip.sharedWithFriendUIDs.isEmpty
        else { return }
        await GoDiveTripShareSync.reconcileOutgoingAcceptances(
            owner: owner,
            modelContext: modelContext
        )
    }

    private func tripPinnedSummary(trip: DiveTrip) -> some View {
        BlueSheetPinnedSummary(
            accent: DiveTripPresentation.formattedDateRange(start: trip.startDate, end: trip.endDate),
            accentColor: cachedTripAccentColor,
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
        NavigationStackPushCoalescing.assignIfNil(target, to: &navigationTarget)
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        TripDetailMapNavigationDebug.openDiveSiteFromMapCalled(siteID: siteID, tripID: trip?.id)

        if let site = TripDetailDiveSiteNavigation.resolvedSite(
            siteID: siteID,
            plannedSites: [],
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
                ActivityMissingDestinationPopView {
                    if case .linkedDive(let id) = navigationTarget, id == diveID {
                        navigationTarget = nil
                    }
                }
            }
        case .diveMedia(let diveID, let mediaID):
            if let activity = linkedDiveActivities.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                ActivityMissingDestinationPopView {
                    if case .diveMedia(let id, _) = navigationTarget, id == diveID {
                        navigationTarget = nil
                    }
                }
            }
        case .buddySharedActivity(let row):
            FriendSharedDiveDetailView(
                dive: row.dive,
                friendName: row.friendDisplayName,
                friendPhotoURL: row.friendPhotoURL,
                friendUID: row.friendUID
            )
        }
    }

    private func catalogSitesForNavigation() -> [DiveSite] {
        guard let trip else { return [] }
        return TripDetailContentSnapshotBuilder.catalogSitesForNavigation(
            trip: trip,
            linkedActivities: linkedDiveActivities
        )
    }
}
