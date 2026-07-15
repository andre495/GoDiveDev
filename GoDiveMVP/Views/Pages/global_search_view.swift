import SwiftData
import SwiftUI

/// App-wide search results — opened from the native **`Tab(role: .search)`** morph tab.
/// **`.searchable`** is on this tab’s **`NavigationStack`** (required for iOS 26 tab-bar morph; do not attach to **`TabView`** or add UIKit stack introspection on the root stack).
struct GlobalSearchView: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.dismissSearch) private var dismissSearch
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = false

    @Binding var query: String
    @Binding var activeContextTokens: [GlobalSearchPresentation.ContextToken]

    let ownerProfileID: UUID?

    @State private var path: [GlobalSearchPresentation.Destination] = []
    @State private var displayedResults = GlobalSearchPresentation.Results(query: "", sections: [])
    @State private var searchTask: Task<Void, Never>?
    @State private var catalogSyncToken = ""
    @State private var isKeyboardVisible = false
    @State private var keyboardOverlapHeight: CGFloat = 0
    @State private var resultsTopChromeHeight = AppTheme.Layout.appHeaderClearanceFallback
    @State private var resultsContainerWidth: CGFloat = 0
    @State private var isResultsPanelVisible = false
    @State private var resultsDismissDragOffset: CGFloat = 0
    @State private var isResultsDismissDragActive = false
    @State private var isStackSearchPresented = true
    @State private var stackSearchRestoreTask: Task<Void, Never>?
    @State private var searchIndexMountTask: Task<Void, Never>?
    @State private var idleBubbleResumeTask: Task<Void, Never>?
    @State private var isSearchIndexMounted = false
    /// Shared built-catalog cache; warmed by a hidden layer after the tab morph so the first scoped
    /// browse (category tile tap) reuses the index instead of building it on the tap.
    @State private var catalogStore = GlobalSearchCatalogStore()
    /// Shared prebuilt Media browse cache; the hidden warmer fills it so the Media tile opens instantly.
    @State private var mediaSnapshotStore = GlobalSearchMediaSnapshotStore()
    @State private var areIdleBubblesPaused = true
    @State private var preservedResultsQuery = ""
    @State private var preservedResultsContextTokens: [GlobalSearchPresentation.ContextToken] = []
    @State private var preservesResultsSessionForDetailPush = false

    init(
        ownerProfileID: UUID?,
        query: Binding<String>,
        activeContextTokens: Binding<[GlobalSearchPresentation.ContextToken]>
    ) {
        self.ownerProfileID = ownerProfileID
        _query = query
        _activeContextTokens = activeContextTokens
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                let safeAreaTop = proxy.safeAreaInsets.top

                ZStack(alignment: .top) {
                    searchStackContent(
                        safeAreaTop: safeAreaTop,
                        containerWidth: proxy.size.width
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    resultsContainerWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, width in
                    resultsContainerWidth = width
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: GlobalSearchPresentation.Destination.self) { destination in
                GlobalSearchSearchDestinationScreen(
                    destination: destination,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: { pushSearchDestination(.dive($0)) }
                )
            }
        }
        .globalSearchStackSearchable(
            isEnabled: GlobalSearchPushedDestinationPresentation.attachesStackSearch(path: path),
            query: $query,
            tokens: $activeContextTokens,
            isPresented: $isStackSearchPresented,
            prompt: stackSearchPrompt
        )
        .globalSearchStackInteractivePopWhenPushed(
            pathCount: path.count
        )
        .softwareKeyboardVisibility($isKeyboardVisible, overlapHeight: $keyboardOverlapHeight)
        .accessibilityIdentifier(GlobalSearchPresentation.rootAccessibilityIdentifier)
        .onAppear {
            syncResultsPanelVisibility(isActive: isSearchActive)
            scheduleDeferredSearchIndexMount()
            scheduleIdleBubbleResume()
        }
        .onChange(of: isSearchActive) { _, isActive in
            if isActive {
                mountSearchIndexImmediatelyIfNeeded()
            }
            syncResultsPanelVisibility(isActive: isActive)
        }
        .onChange(of: path.count) { previousDepth, depth in
            if depth > 0 {
                mountSearchIndexImmediatelyIfNeeded()
            }
            if GlobalSearchPushedDestinationPresentation.shouldDismissNavigationSearchOnPathChange(
                previousDepth: previousDepth,
                newDepth: depth
            ) {
                restorePreservedResultsSessionBindingsIfNeeded()
            }
            if depth > 0 {
                resultsDismissDragOffset = 0
            } else {
                if GlobalSearchPushedDestinationPresentation.shouldForceResultsPanelOnPopFromDetail(
                    previousDepth: previousDepth,
                    newDepth: depth,
                    preservedSessionIsActive: preservesResultsSessionForDetailPush
                ) {
                    restorePreservedResultsSessionBindingsIfNeeded()
                    revealResultsPanelAfterDetailPop()
                }
                syncResultsPanelVisibility(isActive: isSearchActive)
                if GlobalSearchPushedDestinationPresentation.shouldRestoreStackSearchOnPathChange(
                    previousDepth: previousDepth,
                    newDepth: depth,
                    isSearchActive: isSearchActive
                ) {
                    restoreStackSearchPresentationIfNeeded()
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            cancelStackSearchRestore()
            cancelDeferredSearchIndexMount()
            cancelIdleBubbleResume()
        }
    }

    private var isSearchActive: Bool {
        GlobalSearchPresentation.isActive(query: query, contextTokens: activeContextTokens)
    }

    private var stackSearchPrompt: String {
        GlobalSearchPresentation.searchPrompt
    }

    @ViewBuilder
    private func searchStackContent(safeAreaTop: CGFloat, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            genericSearchPage(safeAreaTop: safeAreaTop, containerWidth: containerWidth)

            catalogWarmerLayer

            if isResultsPanelVisible, path.isEmpty {
                searchResultsPanel(safeAreaTop: safeAreaTop, containerWidth: containerWidth)
            }
        }
    }

    /// Invisible layer that loads catalogs + builds the search index into the shared store during idle
    /// time after the tab morph, so the first category tile tap reuses the warm cache instead of
    /// building the index on the tap. Not mounted while the (non-media) results layer is active — that
    /// visible instance owns the cache then; the warmer resumes when the panel is dismissed or media-scoped.
    @ViewBuilder
    private var catalogWarmerLayer: some View {
        let nonMediaResultsActive = isResultsPanelVisible
            && path.isEmpty
            && !GlobalSearchPresentation.isMediaScope(activeContextTokens)
        if isSearchIndexMounted, !nonMediaResultsActive {
            GlobalSearchSearchIndexLayer(
                ownerProfileID: ownerProfileID,
                query: query,
                activeContextTokens: activeContextTokens,
                displayedResults: $displayedResults,
                searchTask: $searchTask,
                catalogSyncToken: $catalogSyncToken,
                resultsTopChromeHeight: $resultsTopChromeHeight,
                automaticallyRenumberDives: automaticallyRenumberDives,
                safeAreaTop: 0,
                resultsDismissDragOffset: 0,
                catalogStore: catalogStore,
                mediaSnapshotStore: mediaSnapshotStore,
                rendersResultsBody: false,
                onPushDestination: pushSearchDestination,
                onBackToCategoryBrowse: finishReturnToGenericSearchPage,
                isResultsDismissDragActive: $isResultsDismissDragActive
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func genericSearchPage(safeAreaTop: CGFloat, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ProfileBubbleBackgroundLayer(animationPaused: areIdleBubblesPaused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            GlobalSearchContextTokensView(
                safeAreaTop: safeAreaTop,
                isKeyboardVisible: isKeyboardVisible,
                keyboardOverlapHeight: keyboardOverlapHeight,
                onSelect: selectContextToken
            )
            .allowsHitTesting(!isResultsPanelVisible && path.isEmpty)
            .accessibilityHidden(isResultsPanelVisible && resultsDismissDragOffset <= 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(
            x: GlobalSearchResultsDismissPresentation.genericBrowseSlideOffset(
                dragOffset: resultsDismissDragOffset,
                containerWidth: containerWidth,
                isResultsPanelVisible: isResultsPanelVisible
            )
        )
    }

    @ViewBuilder
    private func searchResultsPanel(safeAreaTop: CGFloat, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()

            if GlobalSearchPresentation.isMediaScope(activeContextTokens) {
                GlobalSearchMediaResultsView(
                    ownerProfileID: ownerProfileID,
                    query: $query,
                    snapshotStore: mediaSnapshotStore,
                    safeAreaTop: safeAreaTop,
                    resultsTopChromeHeight: $resultsTopChromeHeight,
                    scrollDisabled: GlobalSearchResultsDismissPresentation.locksResultsListScroll(
                        isDismissDragActive: isResultsDismissDragActive,
                        dragOffset: resultsDismissDragOffset
                    ),
                    isSelectionBlocked: GlobalSearchResultsDismissPresentation.blocksResultsRowSelection(
                        isDismissDragActive: isResultsDismissDragActive,
                        dragOffset: resultsDismissDragOffset
                    ),
                    onBack: finishReturnToGenericSearchPage,
                    onOpenDive: { pushSearchDestination(.dive($0)) }
                )
                .allowsHitTesting(
                    !GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
                        isDismissDragActive: isResultsDismissDragActive,
                        dragOffset: resultsDismissDragOffset
                    )
                )
            } else if isSearchIndexMounted {
                GlobalSearchSearchIndexLayer(
                    ownerProfileID: ownerProfileID,
                    query: query,
                    activeContextTokens: activeContextTokens,
                    displayedResults: $displayedResults,
                    searchTask: $searchTask,
                    catalogSyncToken: $catalogSyncToken,
                    resultsTopChromeHeight: $resultsTopChromeHeight,
                    automaticallyRenumberDives: automaticallyRenumberDives,
                    safeAreaTop: safeAreaTop,
                    resultsDismissDragOffset: resultsDismissDragOffset,
                    catalogStore: catalogStore,
                    mediaSnapshotStore: mediaSnapshotStore,
                    onPushDestination: pushSearchDestination,
                    onBackToCategoryBrowse: finishReturnToGenericSearchPage,
                    isResultsDismissDragActive: $isResultsDismissDragActive
                )
                .allowsHitTesting(
                    !GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
                        isDismissDragActive: isResultsDismissDragActive,
                        dragOffset: resultsDismissDragOffset
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: resultsDismissDragOffset)
        .shadow(
            color: .black.opacity(resultsDismissDragOffset > 0 ? 0.18 : 0),
            radius: 18,
            x: -10
        )
        .globalSearchResultsInteractiveDismiss(
            dragOffset: $resultsDismissDragOffset,
            isDragActive: $isResultsDismissDragActive,
            containerWidth: containerWidth,
            onCommitPop: finishReturnToGenericSearchPage
        )
    }

    private func selectContextToken(_ token: GlobalSearchPresentation.ContextToken) {
        mountSearchIndexImmediatelyIfNeeded()
        activeContextTokens = [token]
    }

    private func syncResultsPanelVisibility(isActive: Bool) {
        guard path.isEmpty else { return }

        if isActive {
            mountSearchIndexImmediatelyIfNeeded()
            guard !isResultsPanelVisible else { return }
            resultsDismissDragOffset = GlobalSearchResultsDismissPresentation.initialResultsPanelDragOffsetOnReveal(
                containerWidth: resultsContainerWidth
            )
            isResultsPanelVisible = true
        } else {
            isResultsPanelVisible = false
            resultsDismissDragOffset = 0
        }
    }

    private func pushSearchDestination(_ destination: GlobalSearchPresentation.Destination) {
        if GlobalSearchPushedDestinationPresentation.shouldDismissSearchBeforePathAppend(
            destination: destination,
            currentPathDepth: path.count
        ) {
            dismissSearchChromeForResultPush()
        }
        path.append(destination)
    }

    private func dismissSearchChromeForResultPush() {
        preserveResultsSessionBeforeDetailPush()
        cancelStackSearchRestore()
        isStackSearchPresented = false
        dismissSearch()
        SoftwareKeyboardDismissal.dismissActiveKeyboardIfNeeded()
    }

    private func preserveResultsSessionBeforeDetailPush() {
        preservedResultsQuery = query
        preservedResultsContextTokens = activeContextTokens
        preservesResultsSessionForDetailPush = GlobalSearchPresentation.isActive(
            query: query,
            contextTokens: activeContextTokens
        )
    }

    private func restorePreservedResultsSessionBindingsIfNeeded() {
        guard preservesResultsSessionForDetailPush else { return }
        if query != preservedResultsQuery {
            query = preservedResultsQuery
        }
        if activeContextTokens != preservedResultsContextTokens {
            activeContextTokens = preservedResultsContextTokens
        }
    }

    private func revealResultsPanelAfterDetailPop() {
        isResultsPanelVisible = true
        resultsDismissDragOffset = 0
    }

    private func clearPreservedResultsSession() {
        preservedResultsQuery = ""
        preservedResultsContextTokens = []
        preservesResultsSessionForDetailPush = false
    }

    private func cancelStackSearchRestore() {
        stackSearchRestoreTask?.cancel()
        stackSearchRestoreTask = nil
    }

    /// Re-present tab-bar search after popping from a result — brief delay lets **`.searchable`** reattach.
    private func restoreStackSearchPresentationIfNeeded() {
        cancelStackSearchRestore()
        stackSearchRestoreTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: GlobalSearchPresentation.stackSearchRestoreDelayNanoseconds)
            guard !Task.isCancelled, path.isEmpty else { return }
            restorePreservedResultsSessionBindingsIfNeeded()
            guard isSearchActive else { return }
            isStackSearchPresented = true
        }
    }

    private func finishReturnToGenericSearchPage() {
        let dismissOffset = GlobalSearchResultsDismissPresentation.commitDismissOffset(
            containerWidth: resultsContainerWidth
        )
        withAnimation(
            .spring(
                response: GlobalSearchResultsDismissPresentation.springResponse,
                dampingFraction: GlobalSearchResultsDismissPresentation.springDamping
            )
        ) {
            resultsDismissDragOffset = dismissOffset
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: GlobalSearchResultsDismissPresentation.settleNanoseconds)
            completeReturnToGenericSearchPage()
        }
    }

    private func completeReturnToGenericSearchPage() {
        GlobalSearchPresentation.applyReturnToCategoryBrowse(
            query: &query,
            contextTokens: &activeContextTokens
        )
        displayedResults = GlobalSearchPresentation.Results(query: "", sections: [])
        clearPreservedResultsSession()
        isResultsPanelVisible = false
        resultsDismissDragOffset = 0
        isResultsDismissDragActive = false
        restoreIdleStackSearchPresentation()
    }

    /// Returning to the category tiles restores the same idle state as opening the Search tab fresh: the morphed
    /// tab-bar search field stays visible, but the keyboard is dismissed (field present, not focused).
    private func restoreIdleStackSearchPresentation() {
        SoftwareKeyboardDismissal.dismissActiveKeyboardIfNeeded()
        cancelStackSearchRestore()
        isStackSearchPresented = true
        stackSearchRestoreTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: GlobalSearchPresentation.stackSearchRestoreDelayNanoseconds)
            guard !Task.isCancelled, path.isEmpty else { return }
            isStackSearchPresented = true
        }
    }

    private func mountSearchIndexImmediatelyIfNeeded() {
        guard !isSearchIndexMounted else { return }
        cancelDeferredSearchIndexMount()
        isSearchIndexMounted = true
    }

    private func scheduleDeferredSearchIndexMount() {
        cancelDeferredSearchIndexMount()
        searchIndexMountTask = Task { @MainActor in
            // Wait out the tab-open morph: mounting the warmer runs eight SwiftData fetches, binds
            // the full species + site catalogs, and builds the search index on the main actor — a
            // single yield used to land all of that inside the opening animation's frames.
            try? await Task.sleep(
                nanoseconds: GlobalSearchPresentation.searchIndexWarmMountDelayNanoseconds
            )
            guard !Task.isCancelled, !isSearchIndexMounted else { return }
            isSearchIndexMounted = true
        }
    }

    private func cancelDeferredSearchIndexMount() {
        searchIndexMountTask?.cancel()
        searchIndexMountTask = nil
    }

    private func scheduleIdleBubbleResume() {
        cancelIdleBubbleResume()
        idleBubbleResumeTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: GlobalSearchPresentation.idleBubbleResumeDelayNanoseconds)
            guard !Task.isCancelled else { return }
            areIdleBubblesPaused = false
        }
    }

    private func cancelIdleBubbleResume() {
        idleBubbleResumeTask?.cancel()
        idleBubbleResumeTask = nil
    }

    private static let noOwnerQueryToken = GlobalSearchIndexQueryOwnerID.noProfile
}

private enum GlobalSearchIndexQueryOwnerID {
    static let noProfile = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

/// Shared, main-actor cache for the built search **`Catalog`** so the hidden warmer (mounted after the
/// tab morph) and the visible results layer reuse one index. Building the catalog indexes every dive
/// plus the full bundled OpenDiveMap reference (thousands of sites) on the main actor, so warming it
/// during idle time keeps the first scoped browse (a category tile tap) instant.
@MainActor
final class GlobalSearchCatalogStore {
    var catalog: GlobalSearchPresentation.Catalog?
    var fingerprint = ""
}

/// Shared, main-actor cache of the prebuilt **Search → Media** display cache (index snapshot +
/// unfiltered month sections). The hidden warmer fills it during idle time so tapping the **Media**
/// tile paints the grid from the cache instead of re-capturing every dive/photo/tag on the main
/// actor while the results panel is animating in.
@MainActor
final class GlobalSearchMediaSnapshotStore {
    var displayCache: GlobalSearchMediaBrowsePresentation.DisplayCache?
    /// The `mediaIndexRefreshToken` the cache was captured from (empty until first warm).
    var dataToken = ""
}

/// Fingerprint + build helper shared by the results layer and the warmer so both produce the same
/// cache key and reuse a single stored catalog.
@MainActor
enum GlobalSearchCatalogWarming {
    nonisolated static func fingerprint(
        ownerProfileID: UUID?,
        dives: [DiveActivity],
        diveSites: [DiveSite],
        speciesCatalog: [MarineLife],
        buddies: [DiveBuddy],
        tags: [ActivityTag],
        trips: [DiveTrip],
        equipment: [EquipmentItem],
        certifications: [Certification]
    ) -> String {
        [
            ownerProfileID?.uuidString ?? "none",
            "\(dives.count)",
            "\(diveSites.count)",
            "\(speciesCatalog.count)",
            "\(buddies.count)",
            "\(tags.count)",
            "\(trips.count)",
            "\(equipment.count)",
            "\(certifications.count)",
        ].joined(separator: "|")
    }

    /// Returns the cached catalog when the data fingerprint is unchanged, otherwise builds it once and
    /// stores it. Only the first call for a given fingerprint pays the (expensive) index build.
    @discardableResult
    static func ensureCatalog(
        store: GlobalSearchCatalogStore,
        ownerProfileID: UUID?,
        dives: [DiveActivity],
        diveSites: [DiveSite],
        speciesCatalog: [MarineLife],
        buddies: [DiveBuddy],
        tags: [ActivityTag],
        trips: [DiveTrip],
        equipment: [EquipmentItem],
        certifications: [Certification],
        unitSystem: DiveDisplayUnitSystem
    ) -> GlobalSearchPresentation.Catalog {
        let fingerprint = fingerprint(
            ownerProfileID: ownerProfileID,
            dives: dives,
            diveSites: diveSites,
            speciesCatalog: speciesCatalog,
            buddies: buddies,
            tags: tags,
            trips: trips,
            equipment: equipment,
            certifications: certifications
        )
        if let cached = store.catalog, store.fingerprint == fingerprint {
            return cached
        }
        let catalog = GlobalSearchCatalogSeeding.catalog(
            dives: dives,
            diveSites: diveSites,
            speciesCatalog: speciesCatalog,
            buddies: buddies,
            tags: tags,
            trips: trips,
            equipment: equipment,
            certifications: certifications,
            unitSystem: unitSystem
        )
        store.catalog = catalog
        store.fingerprint = fingerprint
        return catalog
    }
}

/// SwiftData-backed search results surface — mounted after the tab morph so the first frame stays light.
private struct GlobalSearchSearchIndexLayer: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext

    let ownerProfileID: UUID?
    let query: String
    let activeContextTokens: [GlobalSearchPresentation.ContextToken]
    @Binding var displayedResults: GlobalSearchPresentation.Results
    @Binding var searchTask: Task<Void, Never>?
    @Binding var catalogSyncToken: String
    @Binding var resultsTopChromeHeight: CGFloat
    let automaticallyRenumberDives: Bool
    let safeAreaTop: CGFloat
    let resultsDismissDragOffset: CGFloat
    let onPushDestination: (GlobalSearchPresentation.Destination) -> Void
    let onBackToCategoryBrowse: () -> Void
    @Binding var isResultsDismissDragActive: Bool
    /// Shared catalog cache so a hidden warmer instance and the visible results layer reuse one build.
    let catalogStore: GlobalSearchCatalogStore
    /// Shared prebuilt Media browse cache — the hidden warmer fills it; the Media grid reads it on open.
    let mediaSnapshotStore: GlobalSearchMediaSnapshotStore
    /// When `false`, this instance is a hidden warmer: it only loads catalogs + warms the shared cache
    /// (no results body, no search / media work). The visible results instance keeps the default `true`.
    var rendersResultsBody = true

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var ownerTrips: [DiveTrip]
    @Query private var ownerDiveBuddies: [DiveBuddy]
    @Query private var ownerEquipment: [EquipmentItem]
    @Query private var ownerCertifications: [Certification]
    @Query private var ownerActivityTags: [ActivityTag]
    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]
    @Query(sort: [SortDescriptor(\SightingInstance.sightingDateTime, order: .reverse)])
    private var sightings: [SightingInstance]

    @State private var diveSites: [DiveSite] = []
    @State private var speciesCatalog: [MarineLife] = []
    @State private var hasLoadedSearchCatalogs = false
    @State private var mediaDisplayCache: GlobalSearchMediaBrowsePresentation.DisplayCache?
    @State private var mediaIndexRebuildTask: Task<Void, Never>?
    @State private var mediaFilterTask: Task<Void, Never>?
    @State private var mediaGallerySelectedID: UUID?
    /// Data token the cached media snapshot was captured from, so we can reuse the snapshot across
    /// query/token changes and only re-capture on the main actor when the underlying data changes.
    @State private var mediaSnapshotToken = ""
    /// Scroll position of the flat scoped list — fades the back-row count title out as the user scrolls.
    @State private var scopedResultsScrollOffset: CGFloat = 0
    /// Precomputed row content (built once per results change) so scrolling renders cheap `Equatable`
    /// rows instead of re-resolving each row's display data on the main actor every frame.
    @State private var scopedRowContents: [GlobalSearchResultRowContent] = []
    @State private var rowContentByID: [String: GlobalSearchResultRowContent] = [:]

    init(
        ownerProfileID: UUID?,
        query: String,
        activeContextTokens: [GlobalSearchPresentation.ContextToken],
        displayedResults: Binding<GlobalSearchPresentation.Results>,
        searchTask: Binding<Task<Void, Never>?>,
        catalogSyncToken: Binding<String>,
        resultsTopChromeHeight: Binding<CGFloat>,
        automaticallyRenumberDives: Bool,
        safeAreaTop: CGFloat,
        resultsDismissDragOffset: CGFloat,
        catalogStore: GlobalSearchCatalogStore,
        mediaSnapshotStore: GlobalSearchMediaSnapshotStore,
        rendersResultsBody: Bool = true,
        onPushDestination: @escaping (GlobalSearchPresentation.Destination) -> Void,
        onBackToCategoryBrowse: @escaping () -> Void,
        isResultsDismissDragActive: Binding<Bool>
    ) {
        self.ownerProfileID = ownerProfileID
        self.query = query
        self.activeContextTokens = activeContextTokens
        _displayedResults = displayedResults
        _searchTask = searchTask
        _catalogSyncToken = catalogSyncToken
        _resultsTopChromeHeight = resultsTopChromeHeight
        self.automaticallyRenumberDives = automaticallyRenumberDives
        self.safeAreaTop = safeAreaTop
        self.resultsDismissDragOffset = resultsDismissDragOffset
        self.catalogStore = catalogStore
        self.mediaSnapshotStore = mediaSnapshotStore
        self.rendersResultsBody = rendersResultsBody
        self.onPushDestination = onPushDestination
        self.onBackToCategoryBrowse = onBackToCategoryBrowse
        _isResultsDismissDragActive = isResultsDismissDragActive

        let filterOwnerID = ownerProfileID ?? GlobalSearchIndexQueryOwnerID.noProfile
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.id, order: .forward),
            ]
        )
        _ownerDiveBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
        _ownerEquipment = Query(
            filter: #Predicate<EquipmentItem> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\EquipmentItem.manufacturer, order: .forward)]
        )
        _ownerCertifications = Query(
            filter: #Predicate<Certification> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)]
        )
        _ownerActivityTags = Query(
            filter: #Predicate<ActivityTag> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\ActivityTag.name, order: .forward)]
        )
    }

    private var ownerDives: [DiveActivity] {
        ownerDiveActivities
    }

    private var usesFlatScopedResults: Bool {
        activeContextTokens.count == 1 && displayedResults.sections.count == 1
    }

    /// Back-row count header for a scoped category (e.g. "12 Buddies"); `nil` for the multi-category
    /// sectioned list, which carries per-section headers instead.
    private var scopedCountTitle: String? {
        guard usesFlatScopedResults, let token = activeContextTokens.first else { return nil }
        let count = displayedResults.sections.reduce(0) { $0 + $1.hits.count }
        return token.scopedResultsCountTitle(count)
    }

    // MARK: - General-search media section

    /// Media only surfaces in the multi-category (general, unscoped) results — not while a single
    /// category scope is active (which uses the flat list or the dedicated media grid).
    private var isGeneralMediaSearchContext: Bool {
        activeContextTokens.isEmpty && GlobalSearchPresentation.isFiltering(query: query)
    }

    private var filteredMediaIDs: [UUID] {
        mediaDisplayCache?.filteredMediaIDs ?? []
    }

    private var showsMediaSection: Bool {
        isGeneralMediaSearchContext && !filteredMediaIDs.isEmpty
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var mediaSectionItems: [DiveMediaPhoto] {
        let photoByID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.flatMap(\.mediaPhotos).map { ($0.id, $0) }
        )
        return filteredMediaIDs.compactMap { photoByID[$0] }
    }

    private var mediaSectionLinkedItems: [TripDetailLinkedMediaItem] {
        let visibleIDs = Set(filteredMediaIDs)
        return TripDetailMediaPresentation.linkedMediaItems(from: ownerDiveActivities)
            .filter { visibleIDs.contains($0.id) }
    }

    private var mediaSectionTimeZoneOffsets: [UUID: Int?] {
        TripDetailMediaPresentation.timeZoneOffsetByMediaID(
            from: ownerDiveActivities,
            itemIDs: mediaSectionLinkedItems
        )
    }

    private var mediaSectionSightings: [SightingInstance] {
        let visibleIDs = Set(filteredMediaIDs)
        guard !visibleIDs.isEmpty else { return [] }
        let ownerActivityIDs = ownerDiveActivityIDs
        return sightings.filter { sighting in
            guard let activityID = sighting.diveActivityID,
                  ownerActivityIDs.contains(activityID),
                  let mediaPhotoID = sighting.mediaPhotoID
            else { return false }
            return visibleIDs.contains(mediaPhotoID)
        }
    }

    private var mediaSectionBuddyTaggedMediaIDs: Set<UUID> {
        let visibleIDs = Set(filteredMediaIDs)
        guard !visibleIDs.isEmpty else { return [] }
        return Set(
            buddyMediaTags.compactMap { tag -> UUID? in
                guard let mediaPhotoID = tag.mediaPhotoID,
                      visibleIDs.contains(mediaPhotoID) else { return nil }
                return mediaPhotoID
            }
        )
    }

    private var mediaIndexRefreshToken: String {
        "\(ownerDiveActivities.count)|\(buddyMediaTags.count)|\(sightings.count)|\(ownerTrips.count)|\(speciesCatalog.count)"
    }

    var body: some View {
        Group {
            if rendersResultsBody {
                activeSearchResultsBody
            } else {
                // Hidden warmer: no results UI, only the catalog-load + warm tasks below run.
                Color.clear
            }
        }
        .task(id: ownerProfileID) {
            await loadSearchCatalogsIfNeeded()
            await warmSearchCatalogIfNeeded()
            if !rendersResultsBody {
                await warmMediaSnapshotIfNeeded()
            }
        }
        .task(id: mediaIndexRefreshToken) {
            if rendersResultsBody {
                scheduleMediaIndexRebuild()
            } else {
                // Hidden warmer: keep the shared Media browse cache fresh when data changes.
                await warmMediaSnapshotIfNeeded()
            }
        }
        .onChange(of: diveSites.count) { _, _ in
            guard rendersResultsBody else { return }
            scheduleSearchRefresh()
        }
        .onChange(of: speciesCatalog.count) { _, _ in
            guard rendersResultsBody else { return }
            scheduleSearchRefresh()
        }
        .onAppear {
            guard rendersResultsBody else { return }
            // Tapping a category tile is a discrete action — run the scoped browse immediately
            // (no keystroke debounce) so results return without the extra delay.
            scheduleSearchRefresh(immediate: true)
        }
        .onChange(of: query) { _, _ in
            guard rendersResultsBody else { return }
            scheduleSearchRefresh()
            scheduleMediaFilterRebuild()
        }
        .onChange(of: activeContextTokens) { _, _ in
            scopedResultsScrollOffset = 0
            guard rendersResultsBody else { return }
            scheduleSearchRefresh(immediate: true)
            scheduleMediaIndexRebuild()
        }
        .onChange(of: catalogSyncToken) { _, _ in
            guard rendersResultsBody else { return }
            scheduleSearchRefresh()
        }
        .onChange(of: displayedResults) { _, _ in
            guard rendersResultsBody else { return }
            rebuildRowContents()
        }
        .onChange(of: diveDisplayUnitSystem) { _, _ in
            guard rendersResultsBody else { return }
            rebuildRowContents()
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            mediaIndexRebuildTask?.cancel()
            mediaIndexRebuildTask = nil
            mediaFilterTask?.cancel()
            mediaFilterTask = nil
        }
    }

    @ViewBuilder
    private var activeSearchResultsBody: some View {
        ZStack(alignment: .top) {
            Group {
                if displayedResults.isEmpty && !showsMediaSection {
                    Group {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            GlobalSearchEmptyResultsView(
                                title: "No Results",
                                systemImage: "magnifyingglass",
                                description: "Nothing matched this category yet."
                            )
                        } else {
                            GlobalSearchEmptyResultsView(
                                title: "No Results",
                                systemImage: "magnifyingglass",
                                description: "No matches for \"\(query)\"."
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if usesFlatScopedResults {
                    scopedResultsList(
                        scrollDisabled: GlobalSearchResultsDismissPresentation.locksResultsListScroll(
                            isDismissDragActive: isResultsDismissDragActive,
                            dragOffset: resultsDismissDragOffset
                        )
                    )
                } else {
                    sectionedResultsList(
                        scrollDisabled: GlobalSearchResultsDismissPresentation.locksResultsListScroll(
                            isDismissDragActive: isResultsDismissDragActive,
                            dragOffset: resultsDismissDragOffset
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            LogbookTopChromeScrim(
                topObstructionHeight: GlobalSearchPresentation.ResultsChromePresentation.topScrimObstructionHeight(
                    safeAreaTop: safeAreaTop,
                    chromeHeight: resultsTopChromeHeight
                )
            )
            .padding(.top, -safeAreaTop)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .zIndex(GlobalSearchPresentation.ResultsChromePresentation.topScrimZIndex)

            GlobalSearchResultsTopChrome(
                statusBarSafeAreaTop: safeAreaTop,
                trailingTitle: scopedCountTitle,
                trailingTitleAccessibilityIdentifier: "GlobalSearch.Scoped.CountTitle",
                trailingTitleOpacity: GlobalSearchPresentation.ResultsCountTitlePresentation.titleOpacity(
                    scrollOffset: scopedResultsScrollOffset
                ),
                onBack: onBackToCategoryBrowse
            )
            .zIndex(GlobalSearchPresentation.ResultsChromePresentation.topChromeZIndex)
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 {
                resultsTopChromeHeight = height
            }
        }
    }

    private func resultsListTopInsetRow() -> some View {
        Color.clear
            .frame(
                height: GlobalSearchPresentation.ContextTokenPresentation.resultsListTopInset(
                    safeAreaTop: safeAreaTop,
                    chromeHeight: resultsTopChromeHeight
                )
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }

    private func scopedResultsList(scrollDisabled: Bool) -> some View {
        List {
            resultsListTopInsetRow()
            ForEach(scopedRowContents) { content in
                resultRowButton(for: content)
            }
        }
        .globalSearchResultsListChrome()
        .scrollDisabled(scrollDisabled)
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scopedResultsScrollOffset = offset
        }
        .accessibilityIdentifier(GlobalSearchPresentation.resultsListAccessibilityIdentifier)
    }

    private func sectionedResultsList(scrollDisabled: Bool) -> some View {
        let textSectionsByKind = Dictionary(
            uniqueKeysWithValues: displayedResults.sections.map { ($0.kind, $0) }
        )
        let pinnedHeaderTopMargin = GlobalSearchPresentation.ResultsSectionHeaderPresentation.scrollContentTopMargin()
        return List {
            ForEach(GlobalSearchPresentation.SectionKind.resultSectionDisplayOrder) { kind in
                if kind == .media {
                    if showsMediaSection {
                        mediaResultsSection()
                    }
                } else if let section = textSectionsByKind[kind] {
                    Section {
                        ForEach(section.hits) { hit in
                            resultRowButton(for: hit)
                        }
                    } header: {
                        GlobalSearchResultsSectionHeader(title: section.title)
                    }
                    .headerProminence(.increased)
                }
            }
        }
        .globalSearchResultsListChrome()
        .contentMargins(.top, pinnedHeaderTopMargin, for: .scrollContent)
        .scrollDisabled(scrollDisabled)
        .accessibilityIdentifier(GlobalSearchPresentation.resultsListAccessibilityIdentifier)
    }

    private func mediaResultsSection() -> some View {
        Section {
            GlobalSearchResultsMediaGrid(
                mediaItems: mediaSectionItems,
                timeZoneOffsetByMediaID: mediaSectionTimeZoneOffsets,
                linkedMediaItems: mediaSectionLinkedItems,
                sightings: mediaSectionSightings,
                marineLifeCatalog: speciesCatalog,
                ownerProfileID: ownerProfileID,
                buddyTaggedMediaIDs: mediaSectionBuddyTaggedMediaIDs,
                gallerySelectedMediaID: $mediaGallerySelectedID,
                isSelectionBlocked: blocksResultsRowSelection,
                onOpenDive: { onPushDestination(.dive($0)) }
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } header: {
            GlobalSearchResultsSectionHeader(
                title: GlobalSearchPresentation.SectionKind.media.title
            )
        }
        .headerProminence(.increased)
    }

    private var blocksResultsRowSelection: Bool {
        GlobalSearchResultsDismissPresentation.blocksResultsRowSelection(
            isDismissDragActive: isResultsDismissDragActive,
            dragOffset: resultsDismissDragOffset
        )
    }

    @ViewBuilder
    private func resultRowButton(for hit: GlobalSearchPresentation.Hit) -> some View {
        if let content = rowContentByID[hit.id] {
            resultRowButton(for: content)
        }
    }

    private func resultRowButton(for content: GlobalSearchResultRowContent) -> some View {
        Button {
            guard !blocksResultsRowSelection else { return }
            onPushDestination(content.destination)
        } label: {
            GlobalSearchResultRowView(content: content)
        }
        .buttonStyle(.plain)
        .disabled(blocksResultsRowSelection)
        .globalSearchResultListRowChrome()
        .accessibilityIdentifier(content.accessibilityIdentifier)
    }

    /// Rebuilds the precomputed, `Equatable` row content once per results change (or unit-system change)
    /// so scrolling renders cheap value types instead of re-resolving each row on the main actor.
    private func rebuildRowContents() {
        let hits = displayedResults.sections.flatMap(\.hits)
        let contents = GlobalSearchResultRowContentBuilder.rowContents(
            hits: hits,
            ownerProfileID: ownerProfileID,
            ownerDives: ownerDives,
            diveSites: diveSites,
            speciesCatalog: speciesCatalog,
            ownerDiveBuddies: ownerDiveBuddies,
            ownerTrips: ownerTrips,
            ownerEquipment: ownerEquipment,
            ownerCertifications: ownerCertifications,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives
        )
        scopedRowContents = contents
        rowContentByID = Dictionary(contents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// - Parameter immediate: when `true` (discrete actions like a category tile tap or scope change),
    ///   skip the keystroke debounce so results return without extra latency.
    private func scheduleSearchRefresh(immediate: Bool = false) {
        searchTask?.cancel()
        let trimmedQuery = query
        let contextTokens = activeContextTokens
        guard GlobalSearchTabLaunchPresentation.shouldBuildSearchCatalog(
            isSearchActive: GlobalSearchPresentation.isActive(query: trimmedQuery, contextTokens: contextTokens)
        ) else {
            displayedResults = GlobalSearchPresentation.Results(query: trimmedQuery, sections: [])
            return
        }

        catalogSyncToken = catalogFingerprint

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: CatalogSearchPresentation.debounceNanoseconds)
                guard !Task.isCancelled else { return }
            }
            if diveSites.isEmpty || speciesCatalog.isEmpty {
                await loadSearchCatalogsIfNeeded()
            }
            guard !Task.isCancelled else { return }
            // Reuse the cached catalog across keystrokes / taps; only the off-main `search()` runs per query.
            let catalog = ensureBuiltCatalog()
            let results = await Task.detached {
                GlobalSearchPresentation.search(
                    catalog: catalog,
                    query: trimmedQuery,
                    contextTokens: contextTokens
                )
            }.value
            guard !Task.isCancelled else { return }
            displayedResults = results
        }
    }

    /// Returns the cached Sendable catalog from the shared store, rebuilding on the main actor only
    /// when the underlying data fingerprint changes. Query keystrokes / repeat taps hit the cache and
    /// skip the expensive index build (all dives + the full OpenDiveMap reference site index).
    private func ensureBuiltCatalog() -> GlobalSearchPresentation.Catalog {
        GlobalSearchCatalogWarming.ensureCatalog(
            store: catalogStore,
            ownerProfileID: ownerProfileID,
            dives: ownerDives,
            diveSites: diveSites,
            speciesCatalog: speciesCatalog,
            buddies: ownerDiveBuddies,
            tags: ownerActivityTags,
            trips: ownerTrips,
            equipment: ownerEquipment,
            certifications: ownerCertifications,
            unitSystem: diveDisplayUnitSystem
        )
    }

    /// Rebuilds the media index snapshot (and applies the current query filter) for the general
    /// results media strip. Skipped while a category scope is active so scoped searches stay light.
    private func scheduleMediaIndexRebuild() {
        mediaIndexRebuildTask?.cancel()
        mediaFilterTask?.cancel()
        // Keep the cached snapshot when leaving general context (display is gated by
        // `showsMediaSection`), so re-entering a general search reuses it instead of re-capturing.
        guard isGeneralMediaSearchContext else { return }
        // Reuse an existing snapshot when the underlying data is unchanged — only re-filter.
        if mediaDisplayCache?.snapshot != nil, mediaSnapshotToken == mediaIndexRefreshToken {
            scheduleMediaFilterRebuild()
            return
        }
        let dataToken = mediaIndexRefreshToken
        mediaIndexRebuildTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let input = GlobalSearchMediaIndexSnapshotBuilder.captureInput(
                activities: ownerDiveActivities,
                buddyMediaTags: buddyMediaTags,
                sightings: sightings,
                ownerTrips: ownerTrips,
                speciesCatalog: speciesCatalog,
                ownerDiveActivityIDs: ownerDiveActivityIDs
            )
            let filter = GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
            let built = await Task.detached {
                GlobalSearchMediaBrowsePresentation.displayCache(from: input, filter: filter)
            }.value
            guard !Task.isCancelled else { return }
            mediaDisplayCache = built
            mediaSnapshotToken = dataToken
        }
    }

    private func scheduleMediaFilterRebuild() {
        guard isGeneralMediaSearchContext else {
            mediaFilterTask?.cancel()
            return
        }
        // Re-capture if the cached snapshot is missing or reflects stale data.
        guard let snapshot = mediaDisplayCache?.snapshot,
              mediaSnapshotToken == mediaIndexRefreshToken else {
            scheduleMediaIndexRebuild()
            return
        }
        let filter = GlobalSearchMediaBrowsePresentation.resolveFilter(from: query)
        if mediaDisplayCache?.filterFingerprint == GlobalSearchMediaBrowsePresentation.filterFingerprint(filter) {
            return
        }
        mediaFilterTask?.cancel()
        mediaFilterTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            let built = await Task.detached {
                GlobalSearchMediaBrowsePresentation.displayCache(snapshot: snapshot, filter: filter)
            }.value
            guard !Task.isCancelled else { return }
            mediaDisplayCache = built
        }
    }

    /// Builds and caches the catalog once after data loads (deferred a frame) so the first search /
    /// scoped browse is instant instead of paying the full index build on the first keystroke.
    private func warmSearchCatalogIfNeeded() async {
        guard catalogStore.catalog == nil || catalogStore.fingerprint != catalogFingerprint else { return }
        // Decode the ~3,100-row OpenDiveMap reference JSON off the main actor first — the index
        // build below reads it from the warm cache instead of paying the decode on main.
        await Task.detached(priority: .utility) {
            _ = DiveSiteReferenceCatalog.bundledReferenceByID()
        }.value
        await Task.yield()
        guard !Task.isCancelled else { return }
        _ = ensureBuiltCatalog()
    }

    /// Hidden-warmer counterpart of `scheduleMediaIndexRebuild`: prebuilds the **Search → Media**
    /// browse cache into the shared store during idle time, so the Media tile tap paints from the
    /// cache instead of walking every dive/photo/tag on the main actor during the panel slide-in.
    private func warmMediaSnapshotIfNeeded() async {
        guard hasLoadedSearchCatalogs else { return }
        let dataToken = mediaIndexRefreshToken
        guard mediaSnapshotStore.dataToken != dataToken else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }
        let input = GlobalSearchMediaIndexSnapshotBuilder.captureInput(
            activities: ownerDiveActivities,
            buddyMediaTags: buddyMediaTags,
            sightings: sightings,
            ownerTrips: ownerTrips,
            speciesCatalog: speciesCatalog,
            ownerDiveActivityIDs: ownerDiveActivityIDs
        )
        // Build the empty filter on the main actor — `ResolvedFilter()` is main-actor isolated
        // under the module's default isolation, so constructing it inside `Task.detached` warns.
        let emptyFilter = GlobalSearchMediaBrowsePresentation.ResolvedFilter()
        let built = await Task.detached {
            GlobalSearchMediaBrowsePresentation.displayCache(from: input, filter: emptyFilter)
        }.value
        guard !Task.isCancelled else { return }
        mediaSnapshotStore.displayCache = built
        mediaSnapshotStore.dataToken = dataToken
    }

    private func loadSearchCatalogsIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedSearchCatalogs || speciesCatalog.isEmpty else { return }
        let container = modelContext.container
        async let marineLifeIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
        async let diveSiteIDs = DiveSiteCatalogLoader.fetchSortedPersistentIDs(container: container)
        speciesCatalog = MarineLifeCatalogLoader.bindModels(
            persistentIDs: await marineLifeIDs,
            modelContext: modelContext
        )
        diveSites = DiveSiteCatalogLoader.bindModels(
            persistentIDs: await diveSiteIDs,
            modelContext: modelContext
        )
        guard !Task.isCancelled else { return }
        hasLoadedSearchCatalogs = true
    }

    private var catalogFingerprint: String {
        GlobalSearchCatalogWarming.fingerprint(
            ownerProfileID: ownerProfileID,
            dives: ownerDives,
            diveSites: diveSites,
            speciesCatalog: speciesCatalog,
            buddies: ownerDiveBuddies,
            tags: ownerActivityTags,
            trips: ownerTrips,
            equipment: ownerEquipment,
            certifications: ownerCertifications
        )
    }
}

/// Pushed search destinations — separate from the idle shell so the tab morph stays instant.
private struct GlobalSearchSearchDestinationScreen: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = false

    let destination: GlobalSearchPresentation.Destination
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var ownerTrips: [DiveTrip]
    @Query private var ownerDiveBuddies: [DiveBuddy]
    @Query private var ownerEquipment: [EquipmentItem]
    @Query private var ownerCertifications: [Certification]
    @Query private var ownerActivityTags: [ActivityTag]

    @State private var diveSites: [DiveSite] = []
    @State private var speciesCatalog: [MarineLife] = []

    init(
        destination: GlobalSearchPresentation.Destination,
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.destination = destination
        self.ownerProfileID = ownerProfileID
        self.onOpenDive = onOpenDive

        let filterOwnerID = ownerProfileID ?? GlobalSearchIndexQueryOwnerID.noProfile
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _ownerTrips = Query(
            filter: #Predicate<DiveTrip> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveTrip.startDate, order: .reverse),
                SortDescriptor(\DiveTrip.id, order: .forward),
            ]
        )
        _ownerDiveBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
        _ownerEquipment = Query(
            filter: #Predicate<EquipmentItem> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\EquipmentItem.manufacturer, order: .forward)]
        )
        _ownerCertifications = Query(
            filter: #Predicate<Certification> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)]
        )
        _ownerActivityTags = Query(
            filter: #Predicate<ActivityTag> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\ActivityTag.name, order: .forward)]
        )
    }

    private var ownerDives: [DiveActivity] {
        ownerDiveActivities
    }

    var body: some View {
        destinationView
            .globalSearchPushedDestinationChrome()
            .task(id: ownerProfileID) {
                let container = modelContext.container
                async let marineLifeIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
                async let diveSiteIDs = DiveSiteCatalogLoader.fetchSortedPersistentIDs(container: container)
                speciesCatalog = MarineLifeCatalogLoader.bindModels(
                    persistentIDs: await marineLifeIDs,
                    modelContext: modelContext
                )
                diveSites = DiveSiteCatalogLoader.bindModels(
                    persistentIDs: await diveSiteIDs,
                    modelContext: modelContext
                )
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .dive(let id):
            if let activity = ownerDives.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                GlobalSearchMissingDestinationView(message: "This dive is no longer in your log.")
            }
        case .diveSite(let id):
            if let site = diveSites.first(where: { $0.id == id }) {
                ExploreDiveSiteDetailView(
                    site: site,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
            } else {
                GlobalSearchMissingDestinationView(message: "This dive site is no longer in the catalog.")
            }
        case .referenceSite(let referenceID):
            if let snapshot = DiveSiteReferenceCatalog.bundledReference().first(where: { $0.id == referenceID }) {
                ExploreReferenceSiteDetailView(snapshot: snapshot)
            } else {
                GlobalSearchMissingDestinationView(message: "This dive site is no longer in the reference catalog.")
            }
        case .species(let uuid):
            if let species = speciesCatalog.first(where: { $0.uuid == uuid }) {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: onOpenDive
                )
            } else {
                GlobalSearchMissingDestinationView(message: "This species is no longer in the catalog.")
            }
        case .buddy(let id):
            if let buddy = ownerDiveBuddies.first(where: { $0.id == id }) {
                ViewDiveBuddyDetails(buddy: buddy)
            } else {
                GlobalSearchMissingDestinationView(message: "This buddy is no longer in your catalog.")
            }
        case .tag(let id):
            if let tag = ownerActivityTags.first(where: { $0.id == id }) {
                ActivityTagDetailView(tag: tag)
            } else {
                GlobalSearchMissingDestinationView(message: "This tag is no longer in your catalog.")
            }
        case .trip(let id):
            if ownerTrips.contains(where: { $0.id == id }) {
                TripDetailView(tripID: id)
            } else {
                GlobalSearchMissingDestinationView(message: "This trip is no longer in your planner.")
            }
        case .equipment(let id):
            if let item = ownerEquipment.first(where: { $0.id == id }) {
                ViewEquipmentDetails(item: item)
            } else {
                GlobalSearchMissingDestinationView(message: "This equipment item is no longer in your locker.")
            }
        case .certification(let id):
            if let certification = ownerCertifications.first(where: { $0.id == id }) {
                ViewCertificationDetails(certification: certification)
            } else {
                GlobalSearchMissingDestinationView(message: "This certification is no longer in your profile.")
            }
        }
    }
}

private struct GlobalSearchContextTokensView: View {
    let safeAreaTop: CGFloat
    let isKeyboardVisible: Bool
    let keyboardOverlapHeight: CGFloat
    let onSelect: (GlobalSearchPresentation.ContextToken) -> Void

    /// Bumps after a tile tap so SwiftUI fires the selection haptic without blocking navigation.
    @State private var categorySelectHapticTick = 0

    private var tokens: [GlobalSearchPresentation.ContextToken] {
        GlobalSearchPresentation.ContextToken.allCases
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = GlobalSearchPresentation.ContextTokenPresentation.self
            let resolvedSafeAreaTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(safeAreaTop)
            let resolvedSafeAreaBottom = AppScrollUnderHeaderListLayout.resolvedSafeAreaBottom(
                geometry.safeAreaInsets.bottom
            )
            let bottomInset = layout.categoryGridBottomInset(
                resolvedSafeAreaBottom: resolvedSafeAreaBottom,
                keyboardOverlapHeight: keyboardOverlapHeight,
                isKeyboardVisible: isKeyboardVisible
            )

            VStack(spacing: layout.headerToGridSpacing) {
                GlobalSearchIdleHeader(statusBarSafeAreaTop: resolvedSafeAreaTop)
                    .padding(.top, resolvedSafeAreaTop)

                categoryGrid
                    .padding(.horizontal, layout.contentHorizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.bottom, bottomInset)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .animation(.easeInOut(duration: 0.25), value: bottomInset)
        }
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(GlobalSearchPresentation.contextTokensAccessibilityIdentifier)
    }

    @ViewBuilder
    private var categoryGrid: some View {
        let layout = GlobalSearchPresentation.ContextTokenPresentation.self
        let columnCount = layout.gridColumnCount
        let rowCount = layout.gridRowCount(
            tokenCount: tokens.count,
            columnCount: columnCount
        )

        VStack(spacing: layout.gridSpacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: layout.gridSpacing) {
                    ForEach(0..<columnCount, id: \.self) { column in
                        let index = row * columnCount + column
                        if index < tokens.count {
                            tokenButton(tokens[index])
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func tokenButton(_ token: GlobalSearchPresentation.ContextToken) -> some View {
        Button {
            // Navigate first — unprepared UIKit impact generators can stall the main actor.
            onSelect(token)
            categorySelectHapticTick &+= 1
        } label: {
            GlobalSearchContextTokenTile(token: token)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: categorySelectHapticTick)
    }
}

struct GlobalSearchResultsTopChrome: View {
    let statusBarSafeAreaTop: CGFloat
    /// Optional trailing title rendered on the back-button row (above the scrim), e.g. the media count title.
    var trailingTitle: String?
    var trailingTitleAccessibilityIdentifier: String?
    /// Fades the trailing title out as the results list scrolls (1 = visible, 0 = hidden).
    var trailingTitleOpacity: Double
    let onBack: () -> Void

    init(
        statusBarSafeAreaTop: CGFloat,
        trailingTitle: String? = nil,
        trailingTitleAccessibilityIdentifier: String? = nil,
        trailingTitleOpacity: Double = 1,
        onBack: @escaping () -> Void
    ) {
        self.statusBarSafeAreaTop = statusBarSafeAreaTop
        self.trailingTitle = trailingTitle
        self.trailingTitleAccessibilityIdentifier = trailingTitleAccessibilityIdentifier
        self.trailingTitleOpacity = trailingTitleOpacity
        self.onBack = onBack
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            SecondaryDestinationBackButton(dismissAction: onBack)
                .accessibilityIdentifier(GlobalSearchPresentation.resultsBackButtonAccessibilityIdentifier)
            if let trailingTitle {
                Text(trailingTitle)
                    .font(
                        .system(
                            size: GlobalSearchPresentation.ResultsSectionHeaderPresentation.titleFontSize,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(trailingTitleOpacity)
                    .accessibilityIdentifier(trailingTitleAccessibilityIdentifier ?? "")
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}

private struct GlobalSearchIdleHeader: View {
    let statusBarSafeAreaTop: CGFloat

    var body: some View {
        Text(GlobalSearchPresentation.ContextTokenPresentation.idleHeaderTitle)
            .font(AppTheme.Typography.headerTitle.weight(.bold))
            .foregroundStyle(AppTheme.Colors.pageTitleForeground)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier(GlobalSearchPresentation.ContextTokenPresentation.idleHeaderAccessibilityIdentifier)
            .accessibilityAddTraits(.isHeader)
            .appTopChromeVerticalPadding()
            .background(alignment: .top) {
                if statusBarSafeAreaTop > 0.5 {
                    AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
                        .ignoresSafeArea(edges: .top)
                }
            }
    }
}

private struct GlobalSearchContextTokenTile: View {
    let token: GlobalSearchPresentation.ContextToken

    private var accentCategoryID: String {
        token.fieldGuideAccentCategoryID
    }

    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: [
                FieldGuideCategoryAccent.gradientTop(accentCategoryID),
                FieldGuideCategoryAccent.gradientBottom(accentCategoryID),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: token.systemImage)
                .font(
                    .system(
                        size: GlobalSearchPresentation.ContextTokenPresentation.iconPointSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(token.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: GlobalSearchPresentation.ContextTokenPresentation.cornerRadius,
                style: .continuous
            )
            .fill(categoryGradient)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: GlobalSearchPresentation.ContextTokenPresentation.cornerRadius,
                style: .continuous
            )
            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(
            color: FieldGuideCategoryAccent.gradientTop(accentCategoryID).opacity(0.35),
            radius: 8,
            y: 4
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(token.title)
        .accessibilityIdentifier(token.accessibilityIdentifier)
    }
}

/// 3-wide media grid for the **Media** section of the general (unscoped) search results. Collapsed to
/// two rows by default; an **Expand** chevron reveals the rest in place (grid grows down, like the
/// Media tile grid). Tapping a thumbnail opens the shared fullscreen viewer.
private struct GlobalSearchResultsMediaGrid: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    var buddyTaggedMediaIDs: Set<UUID> = []
    @Binding var gallerySelectedMediaID: UUID?
    let isSelectionBlocked: Bool
    let onOpenDive: (UUID) -> Void

    @State private var isExpanded = false
    @State private var fullscreenMediaSelection: FullscreenMediaSelection?

    private struct FullscreenMediaSelection: Identifiable {
        let id: UUID
        var tagOverviewMode: DiveActivityMediaLargeDetentMode? = nil
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: LinkedMediaGridPresentation.spacing),
            count: GlobalSearchMediaBrowsePresentation.ResultsSectionGrid.columnCount
        )
    }

    private var visibleMediaItems: [DiveMediaPhoto] {
        let count = GlobalSearchMediaBrowsePresentation.ResultsSectionGrid.visibleCount(
            total: mediaItems.count,
            isExpanded: isExpanded
        )
        return Array(mediaItems.prefix(count))
    }

    private var showsExpandControl: Bool {
        GlobalSearchMediaBrowsePresentation.ResultsSectionGrid.showsExpandControl(total: mediaItems.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            LazyVGrid(columns: gridColumns, spacing: LinkedMediaGridPresentation.spacing) {
                ForEach(visibleMediaItems, id: \.id) { media in
                    gridCellButton(for: media)
                }
            }
            .accessibilityIdentifier("GlobalSearch.Results.MediaGrid")

            if showsExpandControl {
                expandControl
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .fullScreenCover(item: $fullscreenMediaSelection) { selection in
            LinkedMediaFullscreenView(
                mediaItems: mediaItems,
                timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
                linkedMediaItems: linkedMediaItems,
                selectedMediaID: $gallerySelectedMediaID,
                configuration: .trip,
                featuredMediaPhotoID: nil,
                onToggleFeatured: nil,
                sightings: sightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                initialTagOverviewMode: selection.tagOverviewMode,
                onOpenDive: onOpenDive
            )
            .onAppear {
                gallerySelectedMediaID = selection.id
            }
        }
    }

    private func openFullscreen(
        mediaID: UUID,
        tagOverviewMode: DiveActivityMediaLargeDetentMode?
    ) {
        gallerySelectedMediaID = mediaID
        fullscreenMediaSelection = FullscreenMediaSelection(
            id: mediaID,
            tagOverviewMode: tagOverviewMode
        )
    }

    private func gridCellButton(for media: DiveMediaPhoto) -> some View {
        Button {
            guard !isSelectionBlocked else { return }
            openFullscreen(mediaID: media.id, tagOverviewMode: nil)
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        DiveActivityMediaThumbnailView(
                            media: media,
                            size: min(proxy.size.width, proxy.size.height),
                            cornerRadius: LinkedMediaGridPresentation.cornerRadius
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(isSelectionBlocked)
        .overlay {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .linkedMediaGridTagBadges(
                    buddyTagCount: buddyTagCount(for: media.id),
                    marineLifeTagCount: marineLifeTagCount(for: media.id),
                    onBuddyTap: {
                        guard !isSelectionBlocked else { return }
                        openFullscreen(
                            mediaID: media.id,
                            tagOverviewMode: LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: true)
                        )
                    },
                    onMarineLifeTap: {
                        guard !isSelectionBlocked else { return }
                        openFullscreen(
                            mediaID: media.id,
                            tagOverviewMode: LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: false)
                        )
                    }
                )
                .allowsHitTesting(true)
        }
        .accessibilityLabel(gridCellAccessibilityLabel(for: media))
        .accessibilityIdentifier("GlobalSearch.Results.MediaGrid.Item.\(media.id.uuidString)")
    }

    private func marineLifeTagCount(for mediaID: UUID) -> Int {
        sightings.reduce(into: 0) { count, sighting in
            if sighting.mediaPhotoID == mediaID { count += 1 }
        }
    }

    private func buddyTagCount(for mediaID: UUID) -> Int {
        if let dive = mediaItems.first(where: { $0.id == mediaID })?.dive {
            return DiveMediaBuddyTagPresentation.resolvedTaggedBuddies(
                mediaPhotoID: mediaID,
                tags: dive.mediaBuddyTags
            ).count
        }
        return buddyTaggedMediaIDs.contains(mediaID) ? 1 : 0
    }

    private func gridCellAccessibilityLabel(for media: DiveMediaPhoto) -> String {
        let kind = media.resolvedMediaKind == .video ? "Video" : "Photo"
        var parts = [kind]
        if TripDetailMediaGalleryPresentation.showsMarineLifeTagIndicator(
            mediaID: media.id,
            sightings: sightings
        ) {
            parts.append("marine life tagged")
        }
        if buddyTaggedMediaIDs.contains(media.id) {
            parts.append("buddies tagged")
        }
        return parts.joined(separator: ", ")
    }

    private var expandControl: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Collapse" : "Expand")
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelectionBlocked)
        .accessibilityIdentifier("GlobalSearch.Results.MediaGrid.ExpandToggle")
    }
}

private struct GlobalSearchEmptyResultsView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.white)
        } description: {
            Text(description)
                .foregroundStyle(.white.opacity(0.88))
        }
        .background(Color.clear)
    }
}

private struct GlobalSearchMissingDestinationView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }
}

private extension View {
    /// Plain results list — transparent rows, zero system separators, standard screen gradient behind the list.
    func globalSearchResultsListChrome() -> some View {
        listStyle(.plain)
            .listSectionSpacing(0)
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }

    /// Per-row chrome — custom hairlines only (no system list separators).
    func globalSearchResultListRowChrome() -> some View {
        listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(
                top: 0,
                leading: AppTheme.Spacing.lg,
                bottom: 0,
                trailing: AppTheme.Spacing.lg
            ))
    }

    /// Hide system navigation chrome on search pushes — detail pages supply their own back control.
    func globalSearchPushedDestinationChrome() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .hidesBottomTabBarWhenPushed()
    }

    /// Attach stack search only at root — keeps tab-bar morph while avoiding navigation search inset on pushed details.
    @ViewBuilder
    func globalSearchStackSearchable(
        isEnabled: Bool,
        query: Binding<String>,
        tokens: Binding<[GlobalSearchPresentation.ContextToken]>,
        isPresented: Binding<Bool>,
        prompt: String
    ) -> some View {
        if isEnabled {
            searchable(
                text: query,
                tokens: tokens,
                isPresented: isPresented,
                prompt: Text(prompt)
            ) { token in
                Label(token.title, systemImage: token.systemImage)
            }
            .searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }

    /// Interactive pop on the stack while a detail is pushed (root must omit UIKit anchors for morph).
    @ViewBuilder
    func globalSearchStackInteractivePopWhenPushed(pathCount: Int) -> some View {
        if GlobalSearchPushedDestinationPresentation.attachesStackInteractivePop(pathCount: pathCount) {
            navigationInteractivePopGestureForHiddenNavBar()
        } else {
            self
        }
    }

    /// Interactive leading-edge slide-back for search results (mirrors **`NavigationStack`** pop).
    func globalSearchResultsInteractiveDismiss(
        dragOffset: Binding<CGFloat>,
        isDragActive: Binding<Bool>,
        containerWidth: CGFloat,
        onCommitPop: @escaping () -> Void
    ) -> some View {
        modifier(
            GlobalSearchResultsInteractiveDismissModifier(
                dragOffset: dragOffset,
                isDragActive: isDragActive,
                containerWidth: containerWidth,
                onCommitPop: onCommitPop
            )
        )
    }
}

private struct GlobalSearchResultsInteractiveDismissModifier: ViewModifier {
    @Binding var dragOffset: CGFloat
    @Binding var isDragActive: Bool

    let containerWidth: CGFloat
    let onCommitPop: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: GoDiveLeadingEdgeSwipePopMetrics.minimumDragDistance, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragActive {
                        guard GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(
                            startLocationX: value.startLocation.x,
                            translation: value.translation
                        ) else { return }
                        isDragActive = true
                    }
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    guard isDragActive else { return }
                    guard GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                        startLocationX: value.startLocation.x,
                        translation: value.translation
                    ) else {
                        withAnimation(
                            .spring(
                                response: GlobalSearchResultsDismissPresentation.springResponse,
                                dampingFraction: GlobalSearchResultsDismissPresentation.springDamping
                            )
                        ) {
                            dragOffset = 0
                        }
                        Task { @MainActor in
                            try? await Task.sleep(
                                nanoseconds: GlobalSearchResultsDismissPresentation.settleNanoseconds
                            )
                            isDragActive = false
                        }
                        return
                    }
                    onCommitPop()
                }
        )
    }
}
