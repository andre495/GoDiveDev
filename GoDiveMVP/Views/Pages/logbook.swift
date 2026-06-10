import Combine
import SwiftData
import SwiftUI

private enum LogbookRoute: Hashable {
    case addActivity
    case diveDetail(UUID)
    /// Opens the dive detail with the **Media** tab focused on a specific photo at the medium detent.
    case diveMedia(UUID, mediaID: UUID)
}

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Query private var activities: [DiveActivity]
    @Query private var ownerActivityTags: [ActivityTag]
    @Query private var ownerDiveBuddies: [DiveBuddy]

    @State private var path: [LogbookRoute] = []
    @State private var activityPendingDeletion: DiveActivity?
    /// Hides the row immediately; cleared only if background delete fails.
    @State private var optimisticallyRemovedActivityIDs: Set<UUID> = []
    @State private var logbookHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var siteSearchQuery = ""
    @State private var activeTagFilter: String?
    @State private var activeBuddyFilter: String?
    @FocusState private var isSiteSearchFocused: Bool
    @State private var logbookDisplayRows: [DiveLogbookRowDisplayData] = []
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

    private let ownerProfileID: UUID?

    private var isLogbookNavigationStackAtRoot: Bool {
        RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: path.count)
    }

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
        let filterOwnerID = ownerProfileID ?? LogbookView.noOwnerQueryToken
        _activities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _ownerActivityTags = Query(
            filter: #Predicate<ActivityTag> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\ActivityTag.name, order: .forward)]
        )
        _ownerDiveBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private var visibleActivities: [DiveActivity] {
        activities.filter { !optimisticallyRemovedActivityIDs.contains($0.id) }
    }

    private var isFilteringLogbook: Bool {
        DiveLogbookSiteSearch.isFiltering(query: siteSearchQuery)
            || activeTagFilter != nil
            || activeBuddyFilter != nil
    }

    private var tagSuggestions: [LogbookTagSearchSuggestion] {
        LogbookTagSearchPresentation.suggestions(
            catalogTagNames: ownerActivityTags.map(\.name),
            query: siteSearchQuery,
            activeTagFilter: activeTagFilter,
            activeBuddyFilter: activeBuddyFilter
        )
    }

    private var buddySuggestions: [LogbookBuddySearchSuggestion] {
        LogbookBuddySearchPresentation.suggestions(
            catalogBuddyNames: ownerDiveBuddies.map(\.displayName),
            query: siteSearchQuery,
            activeBuddyFilter: activeBuddyFilter,
            activeTagFilter: activeTagFilter
        )
    }

    /// No dives left in the store (accounting for optimistic hides before **`@Query`** catches up).
    private var showsStoredDiveEmptyState: Bool {
        activities.count <= optimisticallyRemovedActivityIDs.count
    }

    private var locksPortraitOrientation: Bool {
        AppPortraitOrientationLockPolicy.locksLogbook(pathIsEmpty: path.isEmpty)
    }

    var body: some View {
        logbookNavigationStack
            .navigationInteractivePopGestureForHiddenNavBar()
            .logbookTabReselectObserver()
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
            .onAppear(perform: handleLogbookRootAppear)
            .onChange(of: activities.count) { _, _ in
                handleActivitiesCountChange()
            }
            .onChange(of: siteSearchQuery) { _, newQuery in
                handleSiteSearchQueryChange(newQuery)
            }
            .onChange(of: activeTagFilter) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: activeBuddyFilter) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: diveDisplayUnitSystem) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: automaticallyRenumberDives) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .portraitOrientationLock(when: locksPortraitOrientation)
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
    }

    private func handleLogbookRootAppear() {
        if RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
            hasPerformedInitialCacheBuild: hasPerformedInitialLogbookCacheBuild,
            hasDisplayRows: !logbookDisplayRows.isEmpty
        ) {
            return
        }
        hasPerformedInitialLogbookCacheBuild = true
        scheduleLogbookCacheRefresh()
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

    private var logbookListSurfaceView: some View {
        LogbookListSurface(
            rows: logbookDisplayRows,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            isFilteringBySiteName: isFilteringLogbook,
            isSiteSearchFocused: isSiteSearchFocused,
            bubbleAnimationPaused: suppressStoreDrivenRefresh || isDiveDeleteInProgress,
            headerClearance: logbookHeaderClearance,
            scrollToTopNonce: listScrollToTopNonce,
            siteSearchQuery: $siteSearchQuery,
            isSiteSearchFocusedBinding: $isSiteSearchFocused,
            tagSuggestions: tagSuggestions,
            buddySuggestions: buddySuggestions,
            activeTagFilter: activeTagFilter,
            activeBuddyFilter: activeBuddyFilter,
            onSelectTagSuggestion: selectTagSuggestion,
            onSelectBuddySuggestion: selectBuddySuggestion,
            onClearConfirmedFilters: clearConfirmedSearchFilters,
            onSwipeDelete: requestDeleteForRow,
            onSelectMediaPreview: openDiveMediaPreview,
            onHeaderClearanceChange: updateLogbookHeaderClearance
        )
        .equatable()
    }

    @ViewBuilder
    private func logbookRouteDestination(route: LogbookRoute) -> some View {
        switch route {
        case .addActivity:
            ActivityUploadView(
                onSuccessfulImport: { diveId in
                    if !path.isEmpty {
                        path.removeLast()
                    }
                    path.append(.diveDetail(diveId))
                },
                onBulkImportComplete: {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                }
            )
        case .diveDetail(let id):
            if let activity = activities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                diveNoLongerInLogText
            }
        case .diveMedia(let id, let mediaID):
            if let activity = activities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                diveNoLongerInLogText
            }
        }
    }

    private var diveNoLongerInLogText: some View {
        Text("This dive is no longer in your log.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    /// Tapping a row's media thumbnail opens the dive's **Media** tab on that photo (medium detent).
    private func openDiveMediaPreview(_ row: DiveLogbookRowDisplayData) {
        guard let mediaID = row.previewMediaPhotoID else { return }
        path.append(.diveMedia(row.id, mediaID: mediaID))
    }

    private func selectTagSuggestion(_ suggestion: LogbookTagSearchSuggestion) {
        activeTagFilter = suggestion.tagName
        activeBuddyFilter = nil
        siteSearchQuery = ""
        isSiteSearchFocused = false
    }

    private func selectBuddySuggestion(_ suggestion: LogbookBuddySearchSuggestion) {
        activeBuddyFilter = suggestion.buddyName
        activeTagFilter = nil
        siteSearchQuery = ""
        isSiteSearchFocused = false
    }

    private func clearConfirmedSearchFilters() {
        activeTagFilter = nil
        activeBuddyFilter = nil
    }

    private func requestDeleteForRow(_ rowID: UUID) {
        activityPendingDeletion = activities.first { $0.id == rowID }
    }

    private func updateLogbookHeaderClearance(_ height: CGFloat) {
        if height > 0 { logbookHeaderClearance = height }
    }

    /// Media attached to a dive (manual upload or import auto-attach) does not change **`activities.count`**,
    /// so rebuild the row cache here to surface the new preview thumbnail without waiting for another trigger.
    /// Skips the duplicate scan because adding media never changes duplicate detection.
    private func handleMediaDidChange() {
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

    private func handleSiteSearchQueryChange(_ newQuery: String) {
        if DiveLogbookSiteSearch.isFiltering(query: newQuery) {
            if activeTagFilter != nil { activeTagFilter = nil }
            if activeBuddyFilter != nil { activeBuddyFilter = nil }
        }
        scheduleLogbookCacheRefresh()
    }

    private func handleLogbookTabReselect() {
        path.removeAll()
        isSiteSearchFocused = false
        clearConfirmedSearchFilters()
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
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
                case .addActivity: return false
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
                        reportProgress: { progress in
                            diveDeleteProgress = progress
                        }
                    )
                    await completeSuccessfulDiveDelete(removedId: id, renumberAfterDelete: renumberAfterDelete)
                } catch {
                    DiveActivityDeletionDebug.failure(diveID: id, error: error, contextLabel: "logbook")
                    DiveActivityDeletionDebug.snapshot(
                        diveID: id,
                        contextLabel: "main-on-failure",
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
        // Keep the optimistic hide until a store fetch confirms the row is gone — never probe **`@Query`** models here.
        if !logbookStoreContainsActivity(id: removedId) {
            optimisticallyRemovedActivityIDs.remove(removedId)
        }
        suppressStoreDrivenRefresh = false
        skipNextActivitiesCountRefresh = true
        _ = renumberAfterDelete
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
        logbookDisplayRows.removeAll { $0.id == removedId }
        guard automaticallyRenumberDives else { return }

        let numberingRows = visibleActivities.map {
            DiveActivityDiveNumbering.NumberingRow(
                id: $0.id,
                startTime: $0.startTime,
                diveNumberExplicitlyNone: $0.diveNumberExplicitlyNone
            )
        }
        let chronologicalNumbers = DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: numberingRows)
        logbookDisplayRows = logbookDisplayRows.map { row in
            guard let number = chronologicalNumbers[row.id] else { return row }
            return DiveLogbookRowDisplayData(
                id: row.id,
                displayName: row.displayName,
                diveNumberLabel: "#\(number)",
                detailLine: row.detailLine,
                showsDuplicateHint: row.showsDuplicateHint,
                previewMediaPhotoID: row.previewMediaPhotoID
            )
        }
    }

    /// Awaitable rebuild used at the end of delete so the dialog stays up until row data matches the store.
    @MainActor
    private func refreshLogbookCacheNow(
        includeDuplicateScan: Bool,
        priority: TaskPriority = .userInitiated
    ) async {
        logbookCacheRefreshGeneration += 1
        let generation = logbookCacheRefreshGeneration
        let seeds = LogbookActivitySnapshotSeeding.seeds(from: visibleActivities)
        let unitSystem = diveDisplayUnitSystem
        let useChronologicalNumbers = automaticallyRenumberDives
        let query = siteSearchQuery
        let tagFilter = activeTagFilter
        let buddyFilter = activeBuddyFilter

        let result = await Task.detached(priority: priority) {
            LogbookDisplayCacheBuilder.build(
                visibleSeeds: seeds,
                siteSearchQuery: query,
                confirmedTagName: tagFilter,
                confirmedBuddyName: buddyFilter,
                unitSystem: unitSystem,
                useChronologicalNumbers: useChronologicalNumbers,
                includeDuplicateScan: includeDuplicateScan
            )
        }.value

        guard generation == logbookCacheRefreshGeneration else { return }
        logbookDisplayRows = result.rows
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
                    () -> (DiveDisplayUnitSystem, Bool, String, String?, String?, [LogbookActivitySnapshotSeed], Int) in
                    (
                        diveDisplayUnitSystem,
                        automaticallyRenumberDives,
                        siteSearchQuery,
                        activeTagFilter,
                        activeBuddyFilter,
                        LogbookActivitySnapshotSeeding.seeds(from: visibleActivities),
                        generation
                    )
                }
                let result = await Task.detached(priority: priority) {
                    LogbookDisplayCacheBuilder.build(
                        visibleSeeds: inputs.5,
                        siteSearchQuery: inputs.2,
                        confirmedTagName: inputs.3,
                        confirmedBuddyName: inputs.4,
                        unitSystem: inputs.0,
                        useChronologicalNumbers: inputs.1,
                        includeDuplicateScan: includeDuplicateScan
                    )
                }.value
                await MainActor.run {
                    guard generation == logbookCacheRefreshGeneration else { return }
                    logbookDisplayRows = result.rows
                    duplicateActivityIds = result.duplicateIds
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
    let rows: [DiveLogbookRowDisplayData]
    let showsStoredDiveEmptyState: Bool
    let isFilteringBySiteName: Bool
    /// Included in **`Equatable`** so **`.equatable()`** still refreshes search chrome when focus changes.
    let isSiteSearchFocused: Bool
    let bubbleAnimationPaused: Bool
    let headerClearance: CGFloat
    let scrollToTopNonce: Int
    @Binding var siteSearchQuery: String
    @FocusState.Binding var isSiteSearchFocusedBinding: Bool
    let tagSuggestions: [LogbookTagSearchSuggestion]
    let buddySuggestions: [LogbookBuddySearchSuggestion]
    let activeTagFilter: String?
    let activeBuddyFilter: String?
    let onSelectTagSuggestion: (LogbookTagSearchSuggestion) -> Void
    let onSelectBuddySuggestion: (LogbookBuddySearchSuggestion) -> Void
    let onClearConfirmedFilters: () -> Void
    let onSwipeDelete: (UUID) -> Void
    let onSelectMediaPreview: (DiveLogbookRowDisplayData) -> Void
    let onHeaderClearanceChange: (CGFloat) -> Void

    static func == (lhs: LogbookListSurface, rhs: LogbookListSurface) -> Bool {
        lhs.equatableInputs == rhs.equatableInputs
    }

    private var equatableInputs: LogbookListSurfaceEquatableInputs {
        LogbookListSurfaceEquatableInputs(
            rows: rows,
            showsStoredDiveEmptyState: showsStoredDiveEmptyState,
            isFilteringBySiteName: isFilteringBySiteName,
            siteSearchQuery: siteSearchQuery,
            activeTagFilter: activeTagFilter,
            activeBuddyFilter: activeBuddyFilter,
            tagSuggestionSignature: tagSuggestions.map(\.id).joined(separator: "|"),
            buddySuggestionSignature: buddySuggestions.map(\.id).joined(separator: "|"),
            isSiteSearchFocused: isSiteSearchFocused,
            bubbleAnimationPaused: bubbleAnimationPaused,
            headerClearance: headerClearance,
            scrollToTopNonce: scrollToTopNonce
        )
    }

    var body: some View {
        GeometryReader { proxy in
            logbookListGeometryContent(proxy: proxy)
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self, perform: onHeaderClearanceChange)
    }

    private func logbookListGeometryContent(proxy: GeometryProxy) -> some View {
        let logbookListTopInset = proxy.safeAreaInsets.top + headerClearance
        let logbookListBottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

        return ZStack {
            logbookListStack(
                topInset: logbookListTopInset,
                bottomInset: logbookListBottomInset,
                safeAreaTop: proxy.safeAreaInsets.top
            )
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .ignoresSafeArea(edges: .bottom)
    }

    private func logbookListStack(topInset: CGFloat, bottomInset: CGFloat, safeAreaTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if !GoDiveUITestConfiguration.isActive {
                WaterBubbleBackground(animationPaused: bubbleAnimationPaused)
            }

            logbookScrollSurface(topInset: topInset, bottomInset: bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LogbookTopChromeScrim(topObstructionHeight: topInset)
                .padding(.top, -safeAreaTop)
                .ignoresSafeArea(edges: .top)
                .zIndex(0.5)

            logbookTopChrome
                .zIndex(1)
        }
    }

    @ViewBuilder
    private func logbookScrollSurface(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if showsStoredDiveEmptyState {
            LogbookStoredEmptyState()
                .padding(.top, topInset)
        } else if rows.isEmpty && isFilteringBySiteName {
            LogbookSearchEmptyState()
                .padding(.top, topInset)
        } else {
            logbookDiveList(topInset: topInset, bottomInset: bottomInset)
        }
    }

    private func logbookDiveList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        List {
            Color.clear
                .frame(height: topInset)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)

            ForEach(rows) { row in
                logbookDiveRow(row)
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
        .animation(nil, value: rows.count)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .logbookListScrollToTopTrigger(nonce: scrollToTopNonce)
    }

    private func logbookDiveRow(_ row: DiveLogbookRowDisplayData) -> some View {
        NavigationLink(value: LogbookRoute.diveDetail(row.id)) {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onSwipeDelete(row.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var logbookTopChrome: some View {
        LogbookTopChrome(
            searchText: $siteSearchQuery,
            isSearchFocused: $isSiteSearchFocusedBinding,
            tagSuggestions: tagSuggestions,
            buddySuggestions: buddySuggestions,
            activeTagFilter: activeTagFilter,
            activeBuddyFilter: activeBuddyFilter,
            onSelectTagSuggestion: onSelectTagSuggestion,
            onSelectBuddySuggestion: onSelectBuddySuggestion,
            onClearConfirmedFilters: onClearConfirmedFilters
        ) {
            NavigationLink(value: LogbookRoute.addActivity) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add activity")
        }
    }
}

private struct LogbookSearchEmptyState: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No matching dives")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Try a different dive site name.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text("Import a dive")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LogbookView(ownerProfileID: nil)
}
