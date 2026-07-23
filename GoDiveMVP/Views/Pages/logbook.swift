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
    @State private var activityPendingDeletion: DiveActivity?
    /// Hides the row immediately; cleared only if background delete fails.
    @State private var optimisticallyRemovedActivityIDs: Set<UUID> = []
    @State private var logbookDisplayItems: [LogbookListDisplayItem] = []
    @State private var logbookMyActivitiesSummary: LogbookMyActivitiesSummary = .empty
    @State private var duplicateActivityIds: Set<UUID> = []
    @State private var logbookCacheRefreshGeneration = 0
    /// While **`true`**, SwiftData **`@Query`** updates do not schedule row rebuilds (delete + background renumber).
    @State private var suppressStoreDrivenRefresh = false
    /// Skips one **`activities.count`** change after delete (optimistic rows already match; avoids O(n²) duplicate rescan).
    @State private var skipNextActivitiesCountRefresh = false
    @State private var isDiveDeleteInProgress = false
    @State private var diveDeleteProgress: Double = 0
    @State private var diveDeleteProgressStartedAt: Date?
    @State private var listScrollToTopNonce = 0
    @State private var hasPerformedInitialLogbookCacheBuild = false
    @State private var logbookFeedScope: LogbookFeedScope = .myActivities
    @State private var myActivitiesKindFilter: LogbookMyActivitiesKindFilter = .all
    @State private var buddyFeedRows: [LogbookBuddyFeedPresentation.Row] = []
    @State private var buddyFeedFriends: [GoDiveFriendGraphService.FriendEdge] = []
    @State private var isBuddyFeedLoading = false
    @State private var buddyFeedLoadGeneration = 0

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
        activities.filter { !optimisticallyRemovedActivityIDs.contains($0.id) }
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
        path = LogbookPendingRouteNavigation.path(afterConsuming: route, currentPath: path)
    }

    private var logbookNavigationStack: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                logbookPageZStack
            }
            .navigationDestination(for: LogbookRoute.self, destination: logbookRouteDestination)
            .restoresRootTabBarWhenStackIsEmpty(isLogbookNavigationStackAtRoot)
            .animation(nil, value: path.count)
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            path.append(.diveSite(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .logbook,
                siteID: siteID,
                pathCountAfterAppend: path.count
            )
        }
        .environment(\.openTripDetail) { tripID in
            path.append(.tripDetail(tripID))
        }
        .environment(\.openTripDetailMedia) { launch in
            path.append(.tripDetailMedia(tripID: launch.tripID, mediaID: launch.mediaID))
        }
        .environment(\.openBuddiesListDetailRoute) { route in
            path.append(.buddiesListDetail(route))
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
        ZStack {
            logbookListSurfaceView

            if let activity = activityPendingDeletion {
                confirmDeleteDiveOverlay(activity: activity)
                    .zIndex(2)
            }

            if isDiveDeleteInProgress {
                LogbookDiveDeleteProgressOverlay(progress: diveDeleteProgress)
                    .zIndex(3)
                    .transition(.opacity)
            }
        }
    }

    private var showsMyActivitiesKindFilterEmptyState: Bool {
        guard logbookFeedScope == .myActivities else { return false }
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
            feedScope: logbookFeedScope,
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
            buddyFeedRows: buddyFeedRows,
            buddyFeedEmptyKind: buddyFeedEmptyKind,
            isBuddyFeedLoading: isBuddyFeedLoading,
            isMyActivitiesLoading: isMyActivitiesLogbookLoading,
            upcomingTripBanner: logbookUpcomingTripBanner,
            myActivitiesSummary: logbookMyActivitiesSummary,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            showsMyActivitiesKindFilterEmptyState: showsMyActivitiesKindFilterEmptyState,
            bubbleAnimationPaused: suppressStoreDrivenRefresh || isDiveDeleteInProgress,
            scrollToTopNonce: listScrollToTopNonce,
            onSwipeDelete: requestDeleteForRow,
            onSelectMediaPreview: openActivityMediaPreview,
            onOpenTrip: { path.append(.tripDetail($0)) },
            onOpenDive: { path.append(.diveDetail($0)) },
            onOpenFriendProfile: { friend in
                path.append(.friendProfile(friend))
            },
            onBuddyFeedRefresh: refreshBuddyFeed
        )
        .equatable()
    }

    private var buddyFeedEmptyKind: LogbookBuddyFeedPresentation.EmptyKind? {
        LogbookBuddyFeedPresentation.emptyKind(
            friends: buddyFeedFriends,
            rows: buddyFeedRows,
            firebaseConfigured: GoDiveFirebaseBootstrap.isConfigured,
            isSignedIn: GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() != nil
        )
    }

    @MainActor
    private func refreshBuddyFeed() async {
        buddyFeedLoadGeneration += 1
        let generation = buddyFeedLoadGeneration
        if buddyFeedRows.isEmpty || buddyFeedFriends.isEmpty {
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
        buddyFeedRows = snapshot.rows
        if let owner = accountSession.currentProfile {
            GoDiveFriendBuddyLinking.syncRosterLinks(
                friends: snapshot.friends,
                owner: owner,
                modelContext: modelContext
            )
        }
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
                diveNoLongerInLogText
            }
        case .snorkelDetail(let id):
            if let activity = snorkelActivities.first(where: { $0.id == id }) {
                ViewSingleSnorkelActivity(activity: activity)
            } else {
                Text("This snorkel is no longer in your log.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .snorkelMedia(let id, let mediaID):
            if let activity = snorkelActivities.first(where: { $0.id == id }) {
                ViewSingleSnorkelActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                Text("This snorkel is no longer in your log.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .diveMedia(let id, let mediaID):
            if let activity = activities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                diveNoLongerInLogText
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
                onOpenDive: { path.append(.diveDetail($0)) }
            )
        case .buddySharedDive(let friendUID, let diveDocumentID):
            if let row = buddyFeedRows.first(where: {
                $0.friendUID == friendUID && $0.dive.id == diveDocumentID
            }) {
                FriendSharedDiveDetailView(dive: row.dive, friendName: row.friendDisplayName)
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
        path.append(.diveDetail(diveId))
    }

    private func openImportedSnorkelDetail(_ snorkelId: UUID) {
        popLogbookImportRouteIfNeeded()
        path.append(.snorkelDetail(snorkelId))
    }

    private func popLogbookImportRouteIfNeeded() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    private var diveNoLongerInLogText: some View {
        Text("This dive is no longer in your log.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    /// Tapping a row's media thumbnail opens activity detail on the **Media** tab for that photo.
    private func openActivityMediaPreview(_ row: DiveLogbookRowDisplayData) {
        guard let mediaID = row.previewMediaPhotoID else { return }
        switch row.activityKind {
        case .scubaDive:
            path.append(.diveMedia(row.id, mediaID: mediaID))
        case .snorkel:
            path.append(.snorkelMedia(row.id, mediaID: mediaID))
        }
    }

    private func requestDeleteForRow(_ rowID: UUID) {
        activityPendingDeletion = activities.first { $0.id == rowID }
    }

    /// Media attached to a dive (manual upload or import auto-attach) does not change **`activities.count`**,
    /// so rebuild the row cache here to surface the new preview thumbnail without waiting for another trigger.
    /// Skips the duplicate scan because adding media never changes duplicate detection.
    private func handleMediaDidChange() {
        guard !suppressStoreDrivenRefresh else { return }
        scheduleLogbookCacheRefresh(includeDuplicateScan: false)
    }

    /// Trip create / auto-link does not change **`activities.count`**, so rebuild grouping here.
    private func handleTripGroupingDidChange() {
        guard !suppressStoreDrivenRefresh else { return }
        scheduleLogbookCacheRefresh(includeDuplicateScan: false)
    }

    private func handleActivitiesCountChange() {
        guard !suppressStoreDrivenRefresh else { return }
        reconcileOptimisticDeletesWithStore()
        if skipNextActivitiesCountRefresh {
            skipNextActivitiesCountRefresh = false
            return
        }
        scheduleLogbookCacheRefresh()
    }

    /// Drops optimistic hides once the store no longer has those dive ids (background delete merged).
    private func reconcileOptimisticDeletesWithStore() {
        guard !optimisticallyRemovedActivityIDs.isEmpty else { return }
        let confirmedRemoved = optimisticallyRemovedActivityIDs.filter { removedID in
            !logbookStoreContainsActivity(id: removedID)
        }
        guard !confirmedRemoved.isEmpty else { return }
        optimisticallyRemovedActivityIDs.subtract(confirmedRemoved)
    }

    /// Predicate fetch — do not read **`@Query`** model properties during merge (can trap on invalidated rows).
    private func logbookStoreContainsActivity(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let fetched = try? modelContext.fetch(descriptor) else { return true }
        return !fetched.isEmpty
    }

    private func handleLogbookTabReselect() {
        path.removeAll()
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
        refreshBuddyFeedWhenBuddyFeedListVisible()
    }

    private func confirmDeleteDiveOverlay(activity: DiveActivity) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        activityPendingDeletion = nil
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Delete dive?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Are you sure? This cannot be undone.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center) {
                    Button("Cancel") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            activityPendingDeletion = nil
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)

                    Spacer(minLength: AppTheme.Spacing.lg)

                    Button("Delete") {
                        confirmDeleteDive(activity)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .buttonStyle(.plain)
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func confirmDeleteDive(_ activity: DiveActivity) {
        let id = activity.id
        let deletedStartTime = activity.startTime
        let container = modelContext.container
        let renumberAfterDelete = automaticallyRenumberDives

        dismissDeleteOverlayImmediately()
        showDiveDeleteProgressUIImmediately()
        DiveActivityDeletionDebug.began(diveID: id)

        Task { @MainActor in
            // Paint the progress dialog before list/navigation updates block the main thread.
            await Task.yield()

            optimisticallyRemovedActivityIDs.insert(id)
            suppressStoreDrivenRefresh = true
            applyOptimisticDeleteToLogbookRows(removedId: id)
            path.removeAll {
                switch $0 {
                case .diveDetail(let detailId): return detailId == id
                case .diveMedia(let detailId, _): return detailId == id
                case .snorkelDetail(let detailId): return detailId == id
                case .snorkelMedia(let detailId, _): return detailId == id
                case .addActivity, .diveActivityUpload, .snorkelActivityUpload, .connectDeviceComingSoon,
                     .tripPlanner, .tripDetail, .tripDetailMedia, .diveSite, .buddySharedDive, .friendProfile, .friends,
                     .buddiesListDetail: return false
                }
            }

            Task(priority: .userInitiated) {
                do {
                    try await DiveActivityDeletion.delete(
                        DiveActivityDeletion.Request(
                            activityID: id,
                            deletedStartTime: deletedStartTime,
                            deletedId: id,
                            renumberAfterDelete: renumberAfterDelete
                        ),
                        container: container,
                        deferRenumber: renumberAfterDelete,
                        mainModelContext: modelContext,
                        reportProgress: { progress in
                            diveDeleteProgress = progress
                        }
                    )
                    await completeSuccessfulDiveDelete(removedId: id, renumberAfterDelete: renumberAfterDelete)
                } catch {
                    DiveActivityDeletionDebug.failure(diveID: id, error: error, contextLabel: "logbook")
                    DiveActivityDeletionDebug.snapshot(
                        diveID: id,
                        contextLabel: "logbook-on-failure",
                        modelContext: modelContext
                    )
                    await revertFailedDiveDelete(removedId: id)
                }
                await endDiveDeleteProgressUI()
            }
        }
    }

    @MainActor
    private func completeSuccessfulDiveDelete(removedId: UUID, renumberAfterDelete: Bool) async {
        if renumberAfterDelete {
            await DivePostDeleteRenumberScheduler.shared.waitForPending()
        }

        let uiSynced = await waitForActivityRemovedFromUIQuery(id: removedId)
        if uiSynced {
            optimisticallyRemovedActivityIDs.remove(removedId)
        }
        suppressStoreDrivenRefresh = false
        skipNextActivitiesCountRefresh = true
        await refreshLogbookCacheNow(includeDuplicateScan: false)
    }

    /// Waits for SwiftData **`@Query`** / main-context fetch to reflect a background delete merge.
    @MainActor
    @discardableResult
    private func waitForActivityRemovedFromUIQuery(id: UUID, timeoutSeconds: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            modelContext.processPendingChanges()
            if !activities.contains(where: { $0.id == id }) { return true }
            if !logbookStoreContainsActivity(id: id) { return true }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    @MainActor
    private func revertFailedDiveDelete(removedId: UUID) async {
        optimisticallyRemovedActivityIDs.remove(removedId)
        suppressStoreDrivenRefresh = false
        await refreshLogbookCacheNow(includeDuplicateScan: true)
    }

    private func showDiveDeleteProgressUIImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            diveDeleteProgress = 0.06
            diveDeleteProgressStartedAt = Date()
            isDiveDeleteInProgress = true
        }
    }

    private func endDiveDeleteProgressUI() async {
        await MainActor.run {
            diveDeleteProgress = 1
        }
        let minVisibleSeconds: TimeInterval = 0.08
        let elapsed = await MainActor.run {
            Date().timeIntervalSince(diveDeleteProgressStartedAt ?? Date())
        }
        let delay = max(0, minVisibleSeconds - elapsed)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.16)) {
                isDiveDeleteInProgress = false
            }
            diveDeleteProgress = 0
            diveDeleteProgressStartedAt = nil
        }
    }

    /// Drops the deleted row immediately; when automatic renumber is on, refreshes **#** labels without a full duplicate scan.
    private func applyOptimisticDeleteToLogbookRows(removedId: UUID) {
        logbookDisplayItems = LogbookTripGrouping.removingDive(id: removedId, from: logbookDisplayItems)
        refreshLogbookMyActivitiesSummaryFromVisibleStore()
        guard automaticallyRenumberDives else { return }

        let numberingRows = visibleActivities.map {
            DiveActivityDiveNumbering.NumberingRow(
                id: $0.id,
                startTime: $0.startTime,
                diveNumberExplicitlyNone: $0.diveNumberExplicitlyNone
            )
        }
        let chronologicalNumbers = DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: numberingRows)
        let labels = Dictionary(uniqueKeysWithValues: chronologicalNumbers.map { ($0.key, "#\($0.value)") })
        logbookDisplayItems = LogbookTripGrouping.applyingDiveNumberLabels(labels, to: logbookDisplayItems)
    }

    /// Awaitable rebuild used at the end of delete so the dialog stays up until row data matches the store.
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
        logbookMyActivitiesSummary = result.myActivitiesSummary
    }

    @MainActor
    private func refreshLogbookMyActivitiesSummaryFromVisibleStore() {
        let seeds = mergedLogbookActivitySeeds()
        logbookMyActivitiesSummary = LogbookMyActivitiesSummaryPresentation.summary(from: seeds)
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
                    logbookMyActivitiesSummary = result.myActivitiesSummary
                }
            }
        }
    }

    /// Removes the confirmation sheet without waiting on a fade or on **`save()`**.
    private func dismissDeleteOverlayImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activityPendingDeletion = nil
        }
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
    let buddyFeedEmptyKind: LogbookBuddyFeedPresentation.EmptyKind?
    let isBuddyFeedLoading: Bool
    let isMyActivitiesLoading: Bool
    let upcomingTripBanner: LogbookUpcomingTripBannerData?
    let myActivitiesSummary: LogbookMyActivitiesSummary
    let showsStoredDiveEmptyState: Bool
    let showsMyActivitiesKindFilterEmptyState: Bool
    let bubbleAnimationPaused: Bool
    let scrollToTopNonce: Int
    let onSwipeDelete: (UUID) -> Void
    let onSelectMediaPreview: (DiveLogbookRowDisplayData) -> Void
    let onOpenTrip: (UUID) -> Void
    let onOpenDive: (UUID) -> Void
    let onOpenFriendProfile: (GoDiveFriendGraphService.FriendEdge) -> Void
    let onBuddyFeedRefresh: () async -> Void

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
            buddyFeedEmptyKind: buddyFeedEmptyKind,
            isBuddyFeedLoading: isBuddyFeedLoading,
            isMyActivitiesLoading: isMyActivitiesLoading,
            upcomingTripBanner: upcomingTripBanner,
            myActivitiesSummary: myActivitiesSummary,
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
                    showsMyActivitiesSummary: LogbookCollapsibleHeaderPresentation.showsMyActivitiesSummaryChrome(
                        feedScope: feedScope,
                        showsStoredDiveEmptyState: showsStoredDiveEmptyState
                    ),
                    isMyActivitiesSummaryLoading: isMyActivitiesLoading,
                    myActivitiesSummary: myActivitiesSummary,
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

    private func handleScrollOffset(_ offset: CGFloat) {
        isHeaderCollapsed = CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: offset)
    }

    @ViewBuilder
    private func logbookScrollSurface(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if feedScope == .buddyFeed {
            logbookBuddyFeedSurface(topInset: topInset, bottomInset: bottomInset)
        } else if showsStoredDiveEmptyState {
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
            handleScrollOffset(offset)
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
            handleScrollOffset(offset)
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
                handleScrollOffset(offset)
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
            handleScrollOffset(offset)
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

            ForEach(buddyFeedRows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    NavigationLink(
                        value: LogbookRoute.buddySharedDive(
                            friendUID: row.friendUID,
                            diveDocumentID: row.dive.id
                        )
                    ) {
                        Text(GoDiveSharedDiveProjectionMapping.displayTitle(for: row.dive))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onOpenFriendProfile(
                            GoDiveFriendGraphService.friendEdge(
                                friendUID: row.friendUID,
                                displayName: row.friendDisplayName
                            )
                        )
                    } label: {
                        Text(row.friendDisplayName)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Text(LogbookBuddyFeedPresentation.subtitle(for: row.dive))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
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
            handleScrollOffset(offset)
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
            handleScrollOffset(offset)
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
            handleScrollOffset(offset)
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onSwipeDelete(row.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
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
