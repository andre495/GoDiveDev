import SwiftData
import SwiftUI

private enum LogbookRoute: Hashable {
    case addActivity
    case diveDetail(UUID)
}

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = false

    @Query private var activities: [DiveActivity]
    @Query private var ownerActivityTags: [ActivityTag]

    @State private var path: [LogbookRoute] = []
    @State private var activityPendingDeletion: DiveActivity?
    /// Hides the row immediately; cleared only if background delete fails.
    @State private var optimisticallyRemovedActivityIDs: Set<UUID> = []
    @State private var logbookHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var siteSearchQuery = ""
    @State private var activeTagFilter: String?
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

    private let ownerProfileID: UUID?

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
    }

    private var visibleActivities: [DiveActivity] {
        activities.filter { !optimisticallyRemovedActivityIDs.contains($0.id) }
    }

    private var isFilteringLogbook: Bool {
        DiveLogbookSiteSearch.isFiltering(query: siteSearchQuery) || activeTagFilter != nil
    }

    private var tagSuggestions: [LogbookTagSearchSuggestion] {
        LogbookTagSearchPresentation.suggestions(
            catalogTagNames: ownerActivityTags.map(\.name),
            query: siteSearchQuery,
            activeTagFilter: activeTagFilter
        )
    }

    /// No dives left in the store (accounting for optimistic hides before **`@Query`** catches up).
    private var showsStoredDiveEmptyState: Bool {
        activities.count <= optimisticallyRemovedActivityIDs.count
    }

    var body: some View {
        logbookNavigationStack
            .navigationInteractivePopGestureForHiddenNavBar()
            .logbookTabReselectObserver()
            .onReceive(NotificationCenter.default.publisher(for: .logbookTabReselected)) { _ in
                handleLogbookTabReselect()
            }
            .onAppear { scheduleLogbookCacheRefresh() }
            .onChange(of: activities.count) { _, _ in
                handleActivitiesCountChange()
            }
            .onChange(of: siteSearchQuery) { _, newQuery in
                handleSiteSearchQueryChange(newQuery)
            }
            .onChange(of: activeTagFilter) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: diveDisplayUnitSystem) { _, _ in
                scheduleLogbookCacheRefresh()
            }
            .onChange(of: automaticallyRenumberDives) { _, _ in
                scheduleLogbookCacheRefresh()
            }
    }

    private var logbookNavigationStack: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                logbookPageZStack
            }
            .navigationDestination(for: LogbookRoute.self, destination: logbookRouteDestination)
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
            activeTagFilter: activeTagFilter,
            onSelectTagSuggestion: selectTagSuggestion,
            onClearTagFilter: clearTagFilter,
            onSwipeDelete: requestDeleteForRow,
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
                Text("This dive is no longer in your log.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        }
    }

    private func selectTagSuggestion(_ suggestion: LogbookTagSearchSuggestion) {
        activeTagFilter = suggestion.tagName
        siteSearchQuery = ""
        isSiteSearchFocused = false
    }

    private func clearTagFilter() {
        activeTagFilter = nil
    }

    private func requestDeleteForRow(_ rowID: UUID) {
        activityPendingDeletion = activities.first { $0.id == rowID }
    }

    private func updateLogbookHeaderClearance(_ height: CGFloat) {
        if height > 0 { logbookHeaderClearance = height }
    }

    private func handleActivitiesCountChange() {
        if skipNextActivitiesCountRefresh {
            skipNextActivitiesCountRefresh = false
            return
        }
        guard !suppressStoreDrivenRefresh else { return }
        scheduleLogbookCacheRefresh()
    }

    private func handleSiteSearchQueryChange(_ newQuery: String) {
        if activeTagFilter != nil, DiveLogbookSiteSearch.isFiltering(query: newQuery) {
            activeTagFilter = nil
        }
        scheduleLogbookCacheRefresh()
    }

    private func handleLogbookTabReselect() {
        path.removeAll()
        isSiteSearchFocused = false
        activeTagFilter = nil
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
                if case .diveDetail(let detailId) = $0 { return detailId == id }
                return false
            }

            Task(priority: .utility) {
                do {
                    try await DiveActivityDeletion.delete(
                        DiveActivityDeletion.Request(
                            activityID: id,
                            deletedStartTime: deletedStartTime,
                            deletedId: id,
                            renumberAfterDelete: renumberAfterDelete
                        ),
                        container: container,
                        mainModelContext: modelContext,
                        reportProgress: { progress in
                            diveDeleteProgress = progress
                        }
                    )
                    await completeSuccessfulDiveDelete(removedId: id, renumberAfterDelete: renumberAfterDelete)
                } catch {
                    await revertFailedDiveDelete(removedId: id)
                }
                await endDiveDeleteProgressUI()
            }
        }
    }

    @MainActor
    private func completeSuccessfulDiveDelete(removedId: UUID, renumberAfterDelete: Bool) async {
        optimisticallyRemovedActivityIDs.remove(removedId)
        suppressStoreDrivenRefresh = false
        skipNextActivitiesCountRefresh = true
        // Row removal and **#** labels were updated optimistically; skip O(n²) duplicate rescan here.
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
        let minVisibleSeconds: TimeInterval = 0.2
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
                showsDuplicateHint: row.showsDuplicateHint
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

        let result = await Task.detached(priority: priority) {
            LogbookDisplayCacheBuilder.build(
                visibleSeeds: seeds,
                siteSearchQuery: query,
                confirmedTagName: tagFilter,
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
                    () -> (DiveDisplayUnitSystem, Bool, String, String?, [LogbookActivitySnapshotSeed], Int) in
                    (
                        diveDisplayUnitSystem,
                        automaticallyRenumberDives,
                        siteSearchQuery,
                        activeTagFilter,
                        LogbookActivitySnapshotSeeding.seeds(from: visibleActivities),
                        generation
                    )
                }
                let result = await Task.detached(priority: priority) {
                    LogbookDisplayCacheBuilder.build(
                        visibleSeeds: inputs.4,
                        siteSearchQuery: inputs.2,
                        confirmedTagName: inputs.3,
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
    let activeTagFilter: String?
    let onSelectTagSuggestion: (LogbookTagSearchSuggestion) -> Void
    let onClearTagFilter: () -> Void
    let onSwipeDelete: (UUID) -> Void
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
            tagSuggestionSignature: tagSuggestions.map(\.id).joined(separator: "|"),
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
        .listRowSpacing(AppTheme.Spacing.md)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .animation(nil, value: rows.count)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: [.top, .bottom])
        .logbookListScrollToTopTrigger(nonce: scrollToTopNonce)
    }

    private func logbookDiveRow(_ row: DiveLogbookRowDisplayData) -> some View {
        NavigationLink(value: LogbookRoute.diveDetail(row.id)) {
            LogbookActivityRow(data: row)
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
            activeTagFilter: activeTagFilter,
            onSelectTagSuggestion: onSelectTagSuggestion,
            onClearTagFilter: onClearTagFilter
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
