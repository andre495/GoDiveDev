import Combine
import SwiftData
import SwiftUI

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AccountSession.self) private var accountSession
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Query private var activities: [DiveActivity]
    @Query private var snorkelActivities: [SnorkelActivity]
    @Query private var ownerTrips: [DiveTrip]

    @State private var diveSiteCatalog: [DiveSite] = []

    @State private var path: [LogbookRoute] = []
    @Binding var pendingRoute: LogbookRoute?
    @State private var logbookDisplayItems: [LogbookListDisplayItem] = []
    @State private var duplicateActivityIds: Set<UUID> = []
    @State private var logbookCacheRefreshGeneration = 0
    @State private var listScrollToTopNonce = 0
    @State private var hasPerformedInitialLogbookCacheBuild = false
    @State private var logbookFeedScope: LogbookFeedScope = .myActivities
    @State private var myActivitiesKindFilter: LogbookMyActivitiesKindFilter = .all
    @State private var buddyFeedAllRows: [LogbookBuddyFeedPresentation.Row] = []
    @State private var buddyFeedDisplayedCount = 0
    @State private var buddyFeedFriends: [GoDiveFriendGraphService.FriendEdge] = []
    @State private var isBuddyFeedLoading = false
    @State private var buddyFeedLoadGeneration = 0

    private var buddyFeedVisibleRows: [LogbookBuddyFeedPresentation.Row] {
        LogbookBuddyFeedPresentation.visibleRows(
            from: buddyFeedAllRows,
            displayedCount: buddyFeedDisplayedCount
        )
    }

    private var buddyFeedHasMoreRows: Bool {
        LogbookBuddyFeedPresentation.hasMoreRows(
            totalRowCount: buddyFeedAllRows.count,
            displayedCount: buddyFeedDisplayedCount
        )
    }

    private let ownerProfileID: UUID?
    private let logbookTabSelectionGeneration: Int
    private let isLogbookTabSelected: Bool

    private var isLogbookNavigationStackAtRoot: Bool {
        RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: path.count)
    }

    init(
        ownerProfileID: UUID?,
        pendingRoute: Binding<LogbookRoute?> = .constant(nil),
        logbookTabSelectionGeneration: Int = 0,
        isLogbookTabSelected: Bool = true
    ) {
        self.ownerProfileID = ownerProfileID
        self.logbookTabSelectionGeneration = logbookTabSelectionGeneration
        self.isLogbookTabSelected = isLogbookTabSelected
        _pendingRoute = pendingRoute
        let filterOwnerID = ownerProfileID ?? LogbookView.noOwnerQueryToken
        _activities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _snorkelActivities = Query(
            filter: #Predicate<SnorkelActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\SnorkelActivity.startTime, order: .reverse),
                SortDescriptor(\SnorkelActivity.id, order: .forward),
            ]
        )
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.id, order: .forward),
            ]
        )
    }

    private var visibleActivities: [DiveActivity] {
        activities
    }

    private var visibleSnorkelActivities: [SnorkelActivity] {
        snorkelActivities
    }

    private var visibleMyActivitiesCount: Int {
        visibleActivities.count + visibleSnorkelActivities.count
    }

    @MainActor
    private func mergedLogbookActivitySeeds() -> [LogbookActivitySnapshotSeed] {
        let merged = LogbookActivitySnapshotSeeding.mergedActivitySeeds(
            dives: visibleActivities,
            snorkels: visibleSnorkelActivities
        )
        return LogbookMyActivitiesKindFilterPresentation.filteredSeeds(
            merged,
            filter: myActivitiesKindFilter
        )
    }

    private var logbookUpcomingTripBanner: LogbookUpcomingTripBannerData? {
        guard LogbookUpcomingTripPresentation.shouldShowInLogbookList(
            isFilteringLogbook: false,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            hasDisplayItems: !logbookDisplayItems.isEmpty
        ) else { return nil }
        return LogbookUpcomingTripPresentation.nearestUpcomingBanner(from: ownerTrips)
    }

    /// No dives left in the store (accounting for optimistic hides before **`@Query`** catches up).
    private var showsStoredDiveEmptyState: Bool {
        visibleMyActivitiesCount == 0
    }

    /// Trip rows / dive ↔ trip links can change without **`activities.count`** changing.
    private var logbookTripGroupingSyncToken: String {
        LogbookTripGroupingSync.syncToken(ownerTrips: ownerTrips, activities: visibleActivities)
    }

    var body: some View {
        attachLogbookStoreObservers(
            to: attachLogbookNotificationObservers(
                to: logbookNavigationStack
                    .navigationInteractivePopGestureForHiddenNavBar()
                    .logbookTabReselectObserver()
            )
        )
    }

    private func attachLogbookNotificationObservers<Content: View>(to content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .logbookTabReselected)) { _ in
                handleLogbookTabReselect()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveActivityMediaDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                handleMediaDidChange()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveTripLogbookGroupingDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                handleTripGroupingDidChange()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .goDiveFriendGraphDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                refreshBuddyFeedWhenBuddyFeedListVisible()
            }
    }

    private func attachLogbookStoreObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear(perform: handleLogbookRootAppear)
            .task(id: ownerProfileID) {
                diveSiteCatalog = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
            }
            .onChange(of: activities.count) { _, _ in
                handleActivitiesCountChange()
            }
            .onChange(of: snorkelActivities.count) { _, _ in
                handleActivitiesCountChange()
            }
            .onChange(of: logbookTripGroupingSyncToken) { _, _ in
                handleTripGroupingDidChange()
            }
            .onChange(of: diveDisplayUnitSystem) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: automaticallyRenumberDives) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: myActivitiesKindFilter) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onAppear(perform: consumePendingLogbookRouteIfNeeded)
            .onChange(of: pendingRoute) { _, _ in
                consumePendingLogbookRouteIfNeeded()
            }
            .onChange(of: logbookFeedScope) { _, scope in
                if scope == .buddyFeed {
                    refreshBuddyFeedIfOnBuddyFeed()
                }
            }
            .onChange(of: logbookTabSelectionGeneration) { _, _ in
                refreshBuddyFeedWhenBuddyFeedListVisible()
                performDeferredLogbookCacheBuildIfNeeded()
            }
            .onChange(of: isLogbookTabSelected) { _, isSelected in
                if isSelected {
                    performDeferredLogbookCacheBuildIfNeeded()
                }
            }
            .onChange(of: path.count) { oldCount, newCount in
                if newCount == 0, oldCount > 0 {
                    refreshBuddyFeedWhenBuddyFeedListVisible()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshBuddyFeedWhenBuddyFeedListVisible()
            }
    }

    private func consumePendingLogbookRouteIfNeeded() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        if case .buddySharedDive(let friendUID, let diveDocumentID) = route {
            openBuddySharedDiveFromPush(friendUID: friendUID, diveDocumentID: diveDocumentID)
            return
        }
        path = LogbookPendingRouteNavigation.path(afterConsuming: route, currentPath: path)
    }

    /// Push-notification deep link: land on **Buddy Feed**, then push the target
    /// activity once its row is loaded so **Back** returns to the feed.
    private func openBuddySharedDiveFromPush(friendUID: String, diveDocumentID: String) {
        logbookFeedScope = .buddyFeed
        path.removeAll()
        Task { @MainActor in
            await refreshBuddyFeed()
            guard LogbookBuddyFeedPresentation.containsRow(
                in: buddyFeedAllRows,
                friendUID: friendUID,
                diveDocumentID: diveDocumentID
            ) else { return }
            pushLogbook(.buddySharedDive(friendUID: friendUID, diveDocumentID: diveDocumentID))
        }
    }

    private var logbookNavigationStack: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                logbookPageZStack
            }
            .navigationDestination(for: LogbookRoute.self, destination: logbookRouteDestination)
            .restoresRootTabBarWhenStackIsEmpty(isLogbookNavigationStackAtRoot)
            .coalescesNavigationStackPathDuplicates($path)
            .animation(nil, value: path.count)
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            pushLogbook(.diveSite(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .logbook,
                siteID: siteID,
                pathCountAfterAppend: path.count
            )
        }
        .environment(\.openTripDetail) { tripID in
            pushLogbook(.tripDetail(tripID))
        }
        .environment(\.openTripDetailMedia) { launch in
            pushLogbook(.tripDetailMedia(tripID: launch.tripID, mediaID: launch.mediaID))
        }
        .environment(\.openBuddiesListDetailRoute) { route in
            pushLogbook(.buddiesListDetail(route))
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ActivityDeleteSuccessPresentation.didDeleteNotification
            )
        ) { _ in
            path.removeAll()
        }
    }

    private func handleLogbookRootAppear() {
        if RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
            hasPerformedInitialCacheBuild: hasPerformedInitialLogbookCacheBuild,
            hasDisplayRows: !logbookDisplayItems.isEmpty
        ) {
            return
        }
        guard LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
            isLogbookTabSelected: isLogbookTabSelected,
            hasPerformedInitialCacheBuild: hasPerformedInitialLogbookCacheBuild
        ) else {
            if logbookDisplayItems.isEmpty, !visibleActivities.isEmpty {
                scheduleLogbookCacheRefresh()
            }
            return
        }
        performDeferredLogbookCacheBuildIfNeeded()
    }

    private func performDeferredLogbookCacheBuildIfNeeded() {
        guard LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
            isLogbookTabSelected: isLogbookTabSelected,
            hasPerformedInitialCacheBuild: hasPerformedInitialLogbookCacheBuild
        ) else {
            return
        }
        hasPerformedInitialLogbookCacheBuild = true
        Task {
            await refreshLogbookCacheNow(includeDuplicateScan: true)
        }
    }

    private var logbookPageZStack: some View {
        logbookListSurfaceView
    }

    private var showsMyActivitiesKindFilterEmptyState: Bool {
        // Pager keeps the My Activities page mounted after first visit — evaluate for that page,
        // not only when the Buddy Feed segment is selected.
        guard !showsStoredDiveEmptyState else { return false }
        guard !isMyActivitiesLogbookLoading else { return false }
        guard logbookDisplayItems.isEmpty else { return false }
        let matching = LogbookMyActivitiesKindFilterPresentation.matchingStoredActivityCount(
            diveCount: visibleActivities.count,
            snorkelCount: visibleSnorkelActivities.count,
            filter: myActivitiesKindFilter
        )
        return matching == 0
    }

    private var isMyActivitiesLogbookLoading: Bool {
        LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
            feedScope: .myActivities,
            visibleDiveCount: visibleActivities.count,
            visibleSnorkelCount: visibleSnorkelActivities.count,
            kindFilter: myActivitiesKindFilter,
            displayItemCount: logbookDisplayItems.count
        )
    }

    private var logbookListSurfaceView: some View {
        LogbookListSurface(
            feedScope: logbookFeedScope,
            feedScopeSelection: $logbookFeedScope,
            myActivitiesKindFilter: $myActivitiesKindFilter,
            items: logbookDisplayItems,
            buddyFeedRows: buddyFeedVisibleRows,
            buddyFeedHasMoreRows: buddyFeedHasMoreRows,
            buddyFeedTotalRowCount: buddyFeedAllRows.count,
            buddyFeedEmptyKind: buddyFeedEmptyKind,
            isBuddyFeedLoading: isBuddyFeedLoading,
            isMyActivitiesLoading: isMyActivitiesLogbookLoading,
            upcomingTripBanner: logbookUpcomingTripBanner,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            showsMyActivitiesKindFilterEmptyState: showsMyActivitiesKindFilterEmptyState,
            bubbleAnimationPaused: false,
            scrollToTopNonce: listScrollToTopNonce,
            onSelectMediaPreview: openActivityMediaPreview,
            onOpenTrip: { pushLogbook(.tripDetail($0)) },
            onOpenDive: { pushLogbook(.diveDetail($0)) },
            onOpenFriendProfile: { friend in
                pushLogbook(.friendProfile(friend))
            },
            onBuddyFeedRefresh: refreshBuddyFeed,
            onBuddyFeedLoadMore: loadMoreBuddyFeedRowsIfNeeded
        )
        .equatable()
    }

    private var buddyFeedEmptyKind: LogbookBuddyFeedPresentation.EmptyKind? {
        LogbookBuddyFeedPresentation.emptyKind(
            friends: buddyFeedFriends,
            rows: buddyFeedAllRows,
            firebaseConfigured: GoDiveFirebaseBootstrap.isConfigured,
            isSignedIn: GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() != nil
        )
    }

    @MainActor
    private func refreshBuddyFeed() async {
        buddyFeedLoadGeneration += 1
        let generation = buddyFeedLoadGeneration
        if buddyFeedAllRows.isEmpty || buddyFeedFriends.isEmpty {
            isBuddyFeedLoading = true
        }
        defer {
            if generation == buddyFeedLoadGeneration {
                isBuddyFeedLoading = false
            }
        }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        let snapshot = await GoDiveSharedDiveProjectionSync.fetchBuddyFeedSnapshot()
        guard generation == buddyFeedLoadGeneration else { return }
        buddyFeedFriends = snapshot.friends
        buddyFeedAllRows = snapshot.rows
        buddyFeedDisplayedCount = LogbookBuddyFeedPresentation.initialDisplayedCount(
            for: snapshot.rows.count
        )
        if let owner = accountSession.currentProfile {
            GoDiveFriendBuddyLinking.syncRosterLinks(
                friends: snapshot.friends,
                owner: owner,
                modelContext: modelContext
            )
        }
    }

    @MainActor
    private func loadMoreBuddyFeedRowsIfNeeded() {
        let nextCount = LogbookBuddyFeedPresentation.nextDisplayedCount(
            current: buddyFeedDisplayedCount,
            totalRowCount: buddyFeedAllRows.count
        )
        guard nextCount > buddyFeedDisplayedCount else { return }
        buddyFeedDisplayedCount = nextCount
    }

    private func refreshBuddyFeedIfOnBuddyFeed() {
        guard logbookFeedScope == .buddyFeed else { return }
        Task { await refreshBuddyFeed() }
    }

    /// Refreshes when the buddy feed list is on screen (logbook root + **Buddy Feed** segment).
    private func refreshBuddyFeedWhenBuddyFeedListVisible() {
        guard LogbookBuddyFeedPresentation.shouldAutoRefreshBuddyFeedList(
            feedScope: logbookFeedScope,
            navigationPathCount: path.count,
            isLogbookTabSelected: isLogbookTabSelected
        ) else { return }
        Task { await refreshBuddyFeed() }
    }

    @ViewBuilder
    private func logbookRouteDestination(route: LogbookRoute) -> some View {
        switch route {
        case .addActivity:
            LogbookAddActivityHubView()
        case .diveActivityUpload:
            logbookDiveActivityUploadDestination()
        case .snorkelActivityUpload:
            SnorkelActivityUploadView(
                onSuccessfulImport: { snorkelId in
                    openImportedSnorkelDetail(snorkelId)
                }
            )
        case .connectDeviceComingSoon:
            ConnectDeviceComingSoonView()
        case .tripPlanner:
            TripPlannerView()
        case .diveDetail(let id):
            if let activity = activities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                ActivityMissingDestinationPopView {
                    path = ActivityDeleteSuccessPresentation.logbookPathByRemovingActivity(
                        path,
                        activityID: id
                    )
                }
            }
        case .snorkelDetail(let id):
            if let activity = snorkelActivities.first(where: { $0.id == id }) {
                ViewSingleSnorkelActivity(activity: activity)
            } else {
                ActivityMissingDestinationPopView {
                    path = ActivityDeleteSuccessPresentation.logbookPathByRemovingActivity(
                        path,
                        activityID: id
                    )
                }
            }
        case .snorkelMedia(let id, let mediaID):
            if let activity = snorkelActivities.first(where: { $0.id == id }) {
                ViewSingleSnorkelActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                ActivityMissingDestinationPopView {
                    path = ActivityDeleteSuccessPresentation.logbookPathByRemovingActivity(
                        path,
                        activityID: id
                    )
                }
            }
        case .diveMedia(let id, let mediaID):
            if let activity = activities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                ActivityMissingDestinationPopView {
                    path = ActivityDeleteSuccessPresentation.logbookPathByRemovingActivity(
                        path,
                        activityID: id
                    )
                }
            }
        case .tripDetail(let tripID):
            TripDetailStackNavigationPresentation.tripDetailDestination(tripID: tripID)
        case .tripDetailMedia(let tripID, let mediaID):
            TripDetailStackNavigationPresentation.tripDetailDestination(
                tripID: tripID,
                initialContentPage: .media,
                initialSelectedMediaID: mediaID
            )
        case .diveSite(let siteID):
            ExploreDiveSiteDetailHost(
                siteID: siteID,
                ownerProfileID: ownerProfileID,
                onOpenDive: { pushLogbook(.diveDetail($0)) }
            )
        case .buddySharedDive(let friendUID, let diveDocumentID):
            if let row = buddyFeedAllRows.first(where: {
                $0.friendUID == friendUID && $0.dive.id == diveDocumentID
            }) {
                FriendSharedDiveDetailView(
                    dive: row.dive,
                    friendName: row.friendDisplayName,
                    friendPhotoURL: row.friendPhotoURL,
                    friendUID: row.friendUID
                )
                    .hidesBottomTabBarWhenPushed()
            } else {
                Text("This shared dive is no longer available.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .friendProfile(let friend):
            FriendProfileView(
                friend: friend
            )
        case .friends:
            FriendsListView()
        case .buddiesListDetail(let route):
            BuddiesListNavigationDestinationView(route: route)
                .hidesBottomTabBarWhenPushed()
        }
    }

    private func logbookDiveActivityUploadDestination() -> some View {
        ActivityUploadView(
            onSuccessfulImport: { diveId in
                openImportedDiveDetail(diveId)
            },
            onBulkImportComplete: {
                popLogbookImportRouteIfNeeded()
            }
        )
    }

    private func openImportedDiveDetail(_ diveId: UUID) {
        popLogbookImportRouteIfNeeded()
        pushLogbook(.diveDetail(diveId))
    }

    private func openImportedSnorkelDetail(_ snorkelId: UUID) {
        popLogbookImportRouteIfNeeded()
        pushLogbook(.snorkelDetail(snorkelId))
    }

    private func popLogbookImportRouteIfNeeded() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Tapping a row's media thumbnail opens activity detail on the **Media** tab for that photo.
    private func openActivityMediaPreview(_ row: DiveLogbookRowDisplayData) {
        guard let mediaID = row.previewMediaPhotoID else { return }
        switch row.activityKind {
        case .scubaDive:
            pushLogbook(.diveMedia(row.id, mediaID: mediaID))
        case .snorkel:
            pushLogbook(.snorkelMedia(row.id, mediaID: mediaID))
        }
    }

    private func handleMediaDidChange() {
        scheduleLogbookCacheRefresh(includeDuplicateScan: false)
    }

    /// Trip create / auto-link does not change **`activities.count`**, so rebuild grouping here.
    private func handleTripGroupingDidChange() {
        scheduleLogbookCacheRefresh(includeDuplicateScan: false)
    }

    private func handleActivitiesCountChange() {
        scheduleLogbookCacheRefresh()
    }

    private func handleLogbookTabReselect() {
        path.removeAll()
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
        refreshBuddyFeedWhenBuddyFeedListVisible()
    }

    /// Awaitable rebuild used when the logbook needs an immediate cache refresh.
    @MainActor
    private func refreshLogbookCacheNow(
        includeDuplicateScan: Bool,
        priority: TaskPriority = .userInitiated
    ) async {
        logbookCacheRefreshGeneration += 1
        let generation = logbookCacheRefreshGeneration
        let seeds = mergedLogbookActivitySeeds()
        let tripSeeds = LogbookTripSnapshotSeeding.tripSeeds(
            from: visibleActivities,
            ownerTrips: ownerTrips
        )
        let unitSystem = diveDisplayUnitSystem
        let useChronologicalNumbers = automaticallyRenumberDives

        let result = await Task.detached(priority: priority) {
            LogbookDisplayCacheBuilder.build(
                visibleSeeds: seeds,
                tripSeeds: tripSeeds,
                siteSearchQuery: "",
                confirmedTagName: nil,
                confirmedBuddyName: nil,
                confirmedTripID: nil,
                unitSystem: unitSystem,
                useChronologicalNumbers: useChronologicalNumbers,
                includeDuplicateScan: includeDuplicateScan
            )
        }.value

        guard generation == logbookCacheRefreshGeneration else { return }
        logbookDisplayItems = result.items
        duplicateActivityIds = result.duplicateIds
    }

    private func scheduleLogbookCacheRefresh(
        debounceNanoseconds: UInt64 = 80_000_000,
        priority: TaskPriority = .userInitiated,
        includeDuplicateScan: Bool = true
    ) {
        logbookCacheRefreshGeneration += 1
        let generation = logbookCacheRefreshGeneration

        Task {
            await LogbookCacheRefreshScheduler.shared.schedule(debounceNanoseconds: debounceNanoseconds) {
                await Task.yield()
                let inputs = await MainActor.run {
                    () -> (
                        DiveDisplayUnitSystem,
                        Bool,
                        [LogbookActivitySnapshotSeed],
                        [LogbookTripSnapshotSeed],
                        Int
                    ) in
                    (
                        diveDisplayUnitSystem,
                        automaticallyRenumberDives,
                        mergedLogbookActivitySeeds(),
                        LogbookTripSnapshotSeeding.tripSeeds(
                            from: visibleActivities,
                            ownerTrips: ownerTrips
                        ),
                        generation
                    )
                }
                let result = await Task.detached(priority: priority) {
                    LogbookDisplayCacheBuilder.build(
                        visibleSeeds: inputs.2,
                        tripSeeds: inputs.3,
                        siteSearchQuery: "",
                        confirmedTagName: nil,
                        confirmedBuddyName: nil,
                        confirmedTripID: nil,
                        unitSystem: inputs.0,
                        useChronologicalNumbers: inputs.1,
                        includeDuplicateScan: includeDuplicateScan
                    )
                }.value
                await MainActor.run {
                    guard generation == logbookCacheRefreshGeneration else { return }
                    logbookDisplayItems = result.items
                    duplicateActivityIds = result.duplicateIds
                }
            }
        }
    }

    private func pushLogbook(_ route: LogbookRoute) {
        NavigationStackPushCoalescing.append(route, to: &path)
    }

    /// Sentinel **`ownerProfileID`** so **`@Query`** returns no rows when signed out.
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

// MARK: - List surface (no `@Query` — avoids redrawing bubbles/list on every SwiftData merge)

private struct LogbookListSurface: View, Equatable {
    let feedScope: LogbookFeedScope
    @Binding var feedScopeSelection: LogbookFeedScope
    @Binding var myActivitiesKindFilter: LogbookMyActivitiesKindFilter
    let items: [LogbookListDisplayItem]
    let buddyFeedRows: [LogbookBuddyFeedPresentation.Row]
    let buddyFeedHasMoreRows: Bool
    let buddyFeedTotalRowCount: Int
    let buddyFeedEmptyKind: LogbookBuddyFeedPresentation.EmptyKind?
    let isBuddyFeedLoading: Bool
    let isMyActivitiesLoading: Bool
    let upcomingTripBanner: LogbookUpcomingTripBannerData?
    let showsStoredDiveEmptyState: Bool
    let showsMyActivitiesKindFilterEmptyState: Bool
    let bubbleAnimationPaused: Bool
    let scrollToTopNonce: Int
    let onSelectMediaPreview: (DiveLogbookRowDisplayData) -> Void
    let onOpenTrip: (UUID) -> Void
    let onOpenDive: (UUID) -> Void
    let onOpenFriendProfile: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onBuddyFeedRefresh: () async -> Void
    let onBuddyFeedLoadMore: () -> Void

    @State private var isHeaderCollapsed = false
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    static func == (lhs: LogbookListSurface, rhs: LogbookListSurface) -> Bool {
        lhs.equatableInputs == rhs.equatableInputs
    }

    private var equatableInputs: LogbookListSurfaceEquatableInputs {
        LogbookListSurfaceEquatableInputs(
            feedScope: feedScope,
            myActivitiesKindFilter: myActivitiesKindFilter,
            showsMyActivitiesKindFilterEmptyState: showsMyActivitiesKindFilterEmptyState,
            items: items,
            buddyFeedRows: buddyFeedRows,
            buddyFeedHasMoreRows: buddyFeedHasMoreRows,
            buddyFeedTotalRowCount: buddyFeedTotalRowCount,
            buddyFeedEmptyKind: buddyFeedEmptyKind,
            isBuddyFeedLoading: isBuddyFeedLoading,
            isMyActivitiesLoading: isMyActivitiesLoading,
            upcomingTripBanner: upcomingTripBanner,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            bubbleAnimationPaused: bubbleAnimationPaused,
            scrollToTopNonce: scrollToTopNonce
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let safeAreaTop = proxy.safeAreaInsets.top
            let topInset = safeAreaTop + headerClearance
            let bottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

            ZStack(alignment: .top) {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground(animationPaused: bubbleAnimationPaused)
                }

                logbookScrollSurface(topInset: topInset, bottomInset: bottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                LogbookTopChromeScrim(
                    topObstructionHeight: topInset,
                    featherHeight: CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                )
                .padding(.top, -safeAreaTop)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .zIndex(0.5)

                LogbookCollapsibleHeader(
                    feedScope: $feedScopeSelection,
                    myActivitiesKindFilter: $myActivitiesKindFilter,
                    isCollapsed: isHeaderCollapsed,
                    showsFeedScopeToggle: !isHeaderCollapsed,
                    statusBarSafeAreaTop: safeAreaTop
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea(edges: .bottom)
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
            .onChange(of: scrollToTopNonce) { _, _ in
                expandHeaderForScrollToTop()
            }
        }
    }

    private func expandHeaderForScrollToTop() {
        isHeaderCollapsed = false
    }

    private func handleScrollOffset(_ offset: CGFloat, for scope: LogbookFeedScope) {
        // Off-screen pager page scroll geometry must not collapse / expand the shared header.
        guard feedScopeSelection == scope else { return }
        isHeaderCollapsed = CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: offset)
    }

    private func logbookScrollSurface(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        TabView(selection: $feedScopeSelection) {
            ForEach(LogbookFeedScopePagerPresentation.pages) { scope in
                PushedDetailContentPagerLayout.tabPage {
                    feedScopePage(scope, topInset: topInset, bottomInset: bottomInset)
                }
                .tag(scope)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier(LogbookFeedScopePagerPresentation.accessibilityIdentifier)
    }

    @ViewBuilder
    private func feedScopePage(
        _ scope: LogbookFeedScope,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> some View {
        // Both pages stay mounted (only two scopes) so interactive swipes never flash empty.
        switch scope {
        case .myActivities:
            logbookMyActivitiesSurface(topInset: topInset, bottomInset: bottomInset)
        case .buddyFeed:
            logbookBuddyFeedSurface(topInset: topInset, bottomInset: bottomInset)
        }
    }

    @ViewBuilder
    private func logbookMyActivitiesSurface(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if showsStoredDiveEmptyState {
            logbookStoredEmptyState(topInset: topInset)
        } else if showsMyActivitiesKindFilterEmptyState {
            logbookMyActivitiesKindFilterEmptyState(topInset: topInset)
        } else if isMyActivitiesLoading {
            logbookMyActivitiesLoadingSurface(topInset: topInset)
        } else {
            logbookDiveList(topInset: topInset, bottomInset: bottomInset)
        }
    }

    private func logbookMyActivitiesLoadingSurface(topInset: CGFloat) -> some View {
        ScrollView {
            Color.clear.frame(height: topInset)
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.lg)
                .accessibilityIdentifier(LogbookMyActivitiesSummaryPresentation.loadingAccessibilityIdentifier)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .myActivities)
        }
    }

    private func logbookMyActivitiesKindFilterEmptyState(topInset: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Color.clear
                    .frame(height: topInset)
                    .accessibilityHidden(true)

                LogbookMyActivitiesKindFilterEmptyState(filter: myActivitiesKindFilter)
            }
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .myActivities)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .accessibilityIdentifier("Logbook.MyActivitiesKindFilter.Empty")
    }

    @ViewBuilder
    private func logbookBuddyFeedSurface(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if isBuddyFeedLoading, buddyFeedRows.isEmpty {
            ScrollView {
                Color.clear.frame(height: topInset)
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: [.top, .bottom])
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { offset, _ in
                handleScrollOffset(offset, for: .buddyFeed)
            }
            .accessibilityIdentifier(LogbookBuddyFeedPresentation.buddyFeedRootAccessibilityIdentifier)
            .logbookBuddyFeedPullToRefresh(action: onBuddyFeedRefresh)
        } else if let emptyKind = buddyFeedEmptyKind {
            logbookBuddyFeedEmptyState(topInset: topInset, kind: emptyKind)
        } else {
            logbookBuddyFeedList(topInset: topInset, bottomInset: bottomInset)
        }
    }

    private func logbookBuddyFeedEmptyState(
        topInset: CGFloat,
        kind: LogbookBuddyFeedPresentation.EmptyKind
    ) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Color.clear
                    .frame(height: topInset)
                    .accessibilityHidden(true)

                LogbookBuddyFeedEmptyState(kind: kind)
            }
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .buddyFeed)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .accessibilityIdentifier(LogbookBuddyFeedPresentation.buddyFeedRootAccessibilityIdentifier)
        .logbookBuddyFeedPullToRefresh(action: onBuddyFeedRefresh)
    }

    private func logbookBuddyFeedList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        List {
            Color.clear
                .frame(height: topInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)

            ForEach(Array(buddyFeedRows.enumerated()), id: \.element.id) { index, row in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    LogbookBuddyFeedNavigableTile(row: row) { isolatesHero in
                        NavigationLink(
                            value: LogbookRoute.buddySharedDive(
                                friendUID: row.friendUID,
                                diveDocumentID: row.dive.id
                            )
                        ) {
                            LogbookBuddyFeedTileView(
                                row: row,
                                part: isolatesHero ? .body : .full
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onOpenFriendProfile(
                            GoDiveFriendGraphService.friendEdge(
                                friendUID: row.friendUID,
                                displayName: row.friendDisplayName
                            )
                        )
                    } label: {
                        Text(row.friendDisplayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                }
                .buttonStyle(.plain)
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: AppTheme.Spacing.lg,
                        bottom: AppTheme.Spacing.sm,
                        trailing: AppTheme.Spacing.lg
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onAppear {
                    guard buddyFeedHasMoreRows else { return }
                    guard LogbookBuddyFeedPresentation.shouldLoadNextPage(
                        rowIndex: index,
                        visibleRowCount: buddyFeedRows.count,
                        totalRowCount: buddyFeedTotalRowCount,
                        displayedCount: buddyFeedRows.count
                    ) else { return }
                    onBuddyFeedLoadMore()
                }
                .task(id: row.id) {
                    let thumbURLs = FriendSharedMediaPresentation.buddyFeedThumbnailPrefetchURLs(
                        rows: buddyFeedRows,
                        startIndex: index
                    )
                    let allowsNetwork = AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
                    await GoDiveSharedMediaCache.shared.prefetch(
                        remoteURLStrings: thumbURLs,
                        tier: .thumb,
                        allowsNetworkFetch: allowsNetwork
                    )
                }
            }

            if buddyFeedHasMoreRows {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: AppTheme.Spacing.lg,
                            bottom: AppTheme.Spacing.sm,
                            trailing: AppTheme.Spacing.lg
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        onBuddyFeedLoadMore()
                    }
                    .accessibilityIdentifier(LogbookBuddyFeedPresentation.loadMoreAccessibilityIdentifier)
            }

            Color.clear
                .frame(height: bottomInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .listRowSpacing(AppTheme.Spacing.sm)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .buddyFeed)
        }
        .logbookListScrollToTopTrigger(nonce: scrollToTopNonce)
        .accessibilityIdentifier(LogbookBuddyFeedPresentation.buddyFeedRootAccessibilityIdentifier)
        .logbookBuddyFeedPullToRefresh(action: onBuddyFeedRefresh)
    }

    private func logbookStoredEmptyState(topInset: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Color.clear
                    .frame(height: topInset)
                    .accessibilityHidden(true)

                if let upcomingTripBanner {
                    logbookUpcomingTripBannerLink(upcomingTripBanner)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                LogbookStoredEmptyState()
            }
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .myActivities)
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
    }

    private func logbookDiveList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        List {
            Color.clear
                .frame(height: topInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)

            if let upcomingTripBanner {
                logbookUpcomingTripBannerRow(upcomingTripBanner)
            }

            ForEach(items) { item in
                logbookListItem(item)
            }

            Color.clear
                .frame(height: bottomInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .listRowSpacing(AppTheme.Spacing.sm)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .animation(nil, value: items.count)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { offset, _ in
            handleScrollOffset(offset, for: .myActivities)
        }
        .logbookListScrollToTopTrigger(nonce: scrollToTopNonce)
    }

    private func logbookUpcomingTripBannerRow(_ banner: LogbookUpcomingTripBannerData) -> some View {
        logbookUpcomingTripBannerLink(banner)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: AppTheme.Spacing.lg,
                    bottom: AppTheme.Spacing.sm,
                    trailing: AppTheme.Spacing.lg
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func logbookListItem(_ item: LogbookListDisplayItem) -> some View {
        switch item {
        case .standalone(let row):
            logbookDiveRow(row)
        case .tripGroup(let group):
            logbookTripGroup(group)
        }
    }

    private func logbookTripGroup(_ group: LogbookTripGroupDisplayData) -> some View {
        LogbookTripGroupedDivesView(
            group: group,
            onOpenTrip: onOpenTrip,
            onOpenDive: onOpenDive,
            onSelectMediaPreview: onSelectMediaPreview
        )
        .equatable()
        .listRowInsets(
            EdgeInsets(
                top: 0,
                leading: AppTheme.Spacing.lg,
                bottom: 0,
                trailing: AppTheme.Spacing.lg
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func logbookDiveRow(_ row: DiveLogbookRowDisplayData) -> some View {
        switch row.activityKind {
        case .scubaDive:
            logbookActivityRowLink(row: row, route: .diveDetail(row.id))
        case .snorkel:
            logbookActivityRowLink(row: row, route: .snorkelDetail(row.id))
        }
    }

    private func logbookActivityRowLink(row: DiveLogbookRowDisplayData, route: LogbookRoute) -> some View {
        NavigationLink(value: route) {
            LogbookActivityRow(
                data: row,
                onTapMediaPreview: row.previewMediaPhotoID == nil
                    ? nil
                    : { onSelectMediaPreview(row) }
            )
            .equatable()
        }
        .buttonStyle(.plain)
        .navigationLinkIndicatorVisibility(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: 0,
                leading: AppTheme.Spacing.lg,
                bottom: 0,
                trailing: AppTheme.Spacing.lg
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func logbookUpcomingTripBannerLink(_ banner: LogbookUpcomingTripBannerData) -> some View {
        NavigationLink(value: LogbookRoute.tripDetail(banner.tripID)) {
            LogbookUpcomingTripBannerView(data: banner)
        }
        .buttonStyle(.plain)
        .navigationLinkIndicatorVisibility(.hidden)
    }
}

private struct LogbookMyActivitiesKindFilterEmptyState: View {
    let filter: LogbookMyActivitiesKindFilter

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(LogbookMyActivitiesKindFilterPresentation.emptyStateTitle(filter: filter))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(LogbookMyActivitiesKindFilterPresentation.emptyStateMessage(filter: filter))
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

private struct LogbookBuddyFeedEmptyState: View {
    let kind: LogbookBuddyFeedPresentation.EmptyKind

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            if let buttonTitle = LogbookBuddyFeedPresentation.openFriendsButtonTitle(for: kind) {
                NavigationLink(value: LogbookRoute.friends) {
                    Text(buttonTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .logYourFirstDiveGlassButtonChrome()
                .accessibilityIdentifier(LogbookBuddyFeedPresentation.openFriendsButtonAccessibilityIdentifier)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var iconName: String {
        switch kind {
        case .noFriends, .noSharedDives:
            "person.2.slash"
        case .unavailable:
            "wifi.exclamationmark"
        }
    }

    private var accessibilitySummary: String {
        if let buttonTitle = LogbookBuddyFeedPresentation.openFriendsButtonTitle(for: kind) {
            return "\(title). \(message). \(buttonTitle)."
        }
        return "\(title). \(message)"
    }

    private var title: String {
        switch kind {
        case .noFriends:
            LogbookBuddyFeedPresentation.noFriendsTitle
        case .noSharedDives:
            LogbookBuddyFeedPresentation.noActivitiesTitle
        case .unavailable:
            LogbookBuddyFeedPresentation.unavailableTitle
        }
    }

    private var message: String {
        switch kind {
        case .noFriends:
            LogbookBuddyFeedPresentation.noFriendsMessage
        case .noSharedDives:
            LogbookBuddyFeedPresentation.noActivitiesMessage
        case .unavailable:
            GoDiveFriendsPresentation.firebaseUnavailableMessage
        }
    }
}

private struct LogbookStoredEmptyState: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "water.waves")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dives in your log yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Tap + in the corner to import a dive (.fit or .uddf). Other sources will list dives here the same way as we add them.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            NavigationLink(value: LogbookRoute.addActivity) {
                LogYourFirstDiveGlassButtonLabel()
            }
            .logYourFirstDiveGlassButtonChrome()
            .accessibilityIdentifier("Logbook.Empty.LogFirstDive")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LogbookView(ownerProfileID: nil)
}
