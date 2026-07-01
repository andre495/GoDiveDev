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
            isEnabled: GlobalSearchPushedDestinationPresentation.attachesStackSearch(pathCount: path.count),
            query: $query,
            tokens: $activeContextTokens,
            isPresented: $isStackSearchPresented
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
                preserveResultsSessionBeforeDetailPush()
                cancelStackSearchRestore()
                isStackSearchPresented = false
                dismissSearch()
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

    @ViewBuilder
    private func searchStackContent(safeAreaTop: CGFloat, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            genericSearchPage(safeAreaTop: safeAreaTop, containerWidth: containerWidth)

            if isResultsPanelVisible, path.isEmpty {
                searchResultsPanel(safeAreaTop: safeAreaTop, containerWidth: containerWidth)
            }
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

            if isSearchIndexMounted {
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
            isResultsPanelVisible = true
            let startOffset = GlobalSearchResultsDismissPresentation.commitDismissOffset(
                containerWidth: resultsContainerWidth
            )
            resultsDismissDragOffset = startOffset
            withAnimation(
                .spring(
                    response: GlobalSearchResultsDismissPresentation.springResponse,
                    dampingFraction: GlobalSearchResultsDismissPresentation.springDamping
                )
            ) {
                resultsDismissDragOffset = 0
            }
        } else {
            isResultsPanelVisible = false
            resultsDismissDragOffset = 0
        }
    }

    private func pushSearchDestination(_ destination: GlobalSearchPresentation.Destination) {
        path.append(destination)
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
        isResultsDismissDragActive = false
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
    }

    private func mountSearchIndexImmediatelyIfNeeded() {
        guard !isSearchIndexMounted else { return }
        cancelDeferredSearchIndexMount()
        isSearchIndexMounted = true
    }

    private func scheduleDeferredSearchIndexMount() {
        cancelDeferredSearchIndexMount()
        searchIndexMountTask = Task { @MainActor in
            await Task.yield()
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

/// SwiftData-backed search results surface — mounted after the tab morph so the first frame stays light.
private struct GlobalSearchSearchIndexLayer: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

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

    @Query private var diveSites: [DiveSite]
    @Query private var speciesCatalog: [MarineLife]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @Query private var ownerTrips: [DiveTrip]
    @Query private var ownerDiveBuddies: [DiveBuddy]
    @Query private var ownerEquipment: [EquipmentItem]
    @Query private var ownerCertifications: [Certification]
    @Query private var ownerActivityTags: [ActivityTag]

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
        self.onPushDestination = onPushDestination
        self.onBackToCategoryBrowse = onBackToCategoryBrowse
        _isResultsDismissDragActive = isResultsDismissDragActive

        let filterOwnerID = ownerProfileID ?? GlobalSearchIndexQueryOwnerID.noProfile
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
        guard let ownerProfileID else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerProfileID }
    }

    private var usesFlatScopedResults: Bool {
        activeContextTokens.count == 1 && displayedResults.sections.count == 1
    }

    var body: some View {
        activeSearchResultsBody
            .onAppear {
                scheduleSearchRefresh()
            }
            .onChange(of: query) { _, _ in
                scheduleSearchRefresh()
            }
            .onChange(of: activeContextTokens) { _, _ in
                scheduleSearchRefresh()
            }
            .onChange(of: catalogSyncToken) { _, _ in
                scheduleSearchRefresh()
            }
            .onDisappear {
                searchTask?.cancel()
                searchTask = nil
            }
    }

    @ViewBuilder
    private var activeSearchResultsBody: some View {
        ZStack(alignment: .top) {
            Group {
                if displayedResults.isEmpty {
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
        let hits = displayedResults.sections.flatMap(\.hits)
        return List {
            resultsListTopInsetRow()
            ForEach(hits) { hit in
                resultRowButton(for: hit)
            }
        }
        .globalSearchResultsListChrome()
        .scrollDisabled(scrollDisabled)
        .ignoresSafeArea(edges: .top)
        .accessibilityIdentifier(GlobalSearchPresentation.resultsListAccessibilityIdentifier)
    }

    private func sectionedResultsList(scrollDisabled: Bool) -> some View {
        let sections = displayedResults.sections
        let pinnedHeaderTopMargin = GlobalSearchPresentation.ResultsSectionHeaderPresentation.scrollContentTopMargin(
            chromeHeight: resultsTopChromeHeight
        )
        return List {
            ForEach(sections) { section in
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
        .globalSearchResultsListChrome()
        .contentMargins(.top, pinnedHeaderTopMargin, for: .scrollContent)
        .scrollDisabled(scrollDisabled)
        .accessibilityIdentifier(GlobalSearchPresentation.resultsListAccessibilityIdentifier)
    }

    private func resultRowButton(for hit: GlobalSearchPresentation.Hit) -> some View {
        Button {
            onPushDestination(hit.destination)
        } label: {
            GlobalSearchScopedResultLabel(
                hit: hit,
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
        }
        .buttonStyle(.plain)
        .globalSearchResultListRowChrome()
        .accessibilityIdentifier(hit.accessibilityIdentifier)
    }

    private func scheduleSearchRefresh() {
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
        let catalog = GlobalSearchCatalogSeeding.catalog(
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

        searchTask = Task {
            try? await Task.sleep(nanoseconds: CatalogSearchPresentation.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            let results = GlobalSearchPresentation.search(
                catalog: catalog,
                query: trimmedQuery,
                contextTokens: contextTokens
            )
            await MainActor.run {
                displayedResults = results
            }
        }
    }

    private var catalogFingerprint: String {
        [
            ownerProfileID?.uuidString ?? "none",
            "\(ownerDives.count)",
            "\(diveSites.count)",
            "\(speciesCatalog.count)",
            "\(ownerDiveBuddies.count)",
            "\(ownerActivityTags.count)",
            "\(ownerTrips.count)",
            "\(ownerEquipment.count)",
            "\(ownerCertifications.count)",
        ].joined(separator: "|")
    }
}

/// Pushed search destinations — separate from the idle shell so the tab morph stays instant.
private struct GlobalSearchSearchDestinationScreen: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = false

    let destination: GlobalSearchPresentation.Destination
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @Query private var diveSites: [DiveSite]
    @Query private var speciesCatalog: [MarineLife]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @Query private var ownerTrips: [DiveTrip]
    @Query private var ownerDiveBuddies: [DiveBuddy]
    @Query private var ownerEquipment: [EquipmentItem]
    @Query private var ownerCertifications: [Certification]
    @Query private var ownerActivityTags: [ActivityTag]

    init(
        destination: GlobalSearchPresentation.Destination,
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.destination = destination
        self.ownerProfileID = ownerProfileID
        self.onOpenDive = onOpenDive

        let filterOwnerID = ownerProfileID ?? GlobalSearchIndexQueryOwnerID.noProfile
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
        guard let ownerProfileID else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerProfileID }
    }

    var body: some View {
        destinationView
            .globalSearchPushedDestinationChrome()
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
                GlobalSearchTaggedDivesView(
                    tagName: tag.name,
                    activities: taggedDiveActivities(for: tag),
                    unitSystem: diveDisplayUnitSystem,
                    useChronologicalNumbers: automaticallyRenumberDives,
                    onSelectDive: onOpenDive
                )
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

    private func taggedDiveActivities(for tag: ActivityTag) -> [DiveActivity] {
        ownerDives
            .filter { activity in
                activity.activityTags.contains { $0.id == tag.id }
            }
            .sorted { $0.startTime > $1.startTime }
    }
}

private struct GlobalSearchContextTokensView: View {
    let safeAreaTop: CGFloat
    let isKeyboardVisible: Bool
    let keyboardOverlapHeight: CGFloat
    let onSelect: (GlobalSearchPresentation.ContextToken) -> Void

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
            onSelect(token)
        } label: {
            GlobalSearchContextTokenTile(token: token)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GlobalSearchResultsTopChrome: View {
    let statusBarSafeAreaTop: CGFloat
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            SecondaryDestinationBackButton(dismissAction: onBack)
                .accessibilityIdentifier(GlobalSearchPresentation.resultsBackButtonAccessibilityIdentifier)
            Spacer(minLength: 0)
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
            .foregroundStyle(.white)
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

private struct GlobalSearchResultsSectionHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Color.clear
                .frame(
                    width: GlobalSearchPresentation.ResultsSectionHeaderPresentation.backButtonReservedWidth()
                )
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(title)
                .font(
                    .system(
                        size: GlobalSearchPresentation.ResultsSectionHeaderPresentation.titleFontSize,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .textCase(nil)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, GlobalSearchPresentation.ResultsSectionHeaderPresentation.horizontalPadding)
        .padding(.vertical, GlobalSearchPresentation.ResultsSectionHeaderPresentation.verticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
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

private struct GlobalSearchTaggedDivesView: View {
    let tagName: String
    let activities: [DiveActivity]
    let unitSystem: DiveDisplayUnitSystem
    let useChronologicalNumbers: Bool
    let onSelectDive: (UUID) -> Void

    private var rowData: [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: activities,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: activities
        )
    }

    var body: some View {
        ZStack {
            ProfileBubbleBackgroundLayer()

            if rowData.isEmpty {
                ContentUnavailableView(
                    "No dives",
                    systemImage: "water.waves",
                    description: Text("No dives use the tag \(tagName).")
                )
            } else {
                VStack(spacing: 0) {
                    Text(tagName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)
                        .padding(.bottom, AppTheme.Spacing.sm)
                        .accessibilityAddTraits(.isHeader)

                    List {
                        ForEach(rowData) { data in
                            Button {
                                onSelectDive(data.id)
                            } label: {
                                GlobalSearchDiveResultListRow(data: data)
                            }
                            .buttonStyle(.plain)
                            .globalSearchResultListRowChrome()
                        }
                    }
                    .globalSearchResultsListChrome()
                }
            }
        }
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
        isPresented: Binding<Bool>
    ) -> some View {
        if isEnabled {
            searchable(
                text: query,
                tokens: tokens,
                isPresented: isPresented,
                prompt: Text(GlobalSearchPresentation.searchPrompt)
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
                    guard value.startLocation.x <= GoDiveLeadingEdgeSwipePopMetrics.maxStartXFromScreenLeading else {
                        return
                    }
                    isDragActive = true
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    defer { isDragActive = false }
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
                        return
                    }
                    onCommitPop()
                }
        )
    }
}
