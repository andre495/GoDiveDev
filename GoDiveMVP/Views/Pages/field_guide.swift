import SwiftData
import SwiftUI

private enum FieldGuideRoute: Hashable {
    case category(FieldGuideCatalogIndex.CategorySummary)
    case subcategory(FieldGuideCatalogIndex.SubcategoryBrowsePayload)
    case speciesDetail(String)
    case diveDetail(UUID)
    case diveSite(UUID)
}

struct FieldGuideView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext

    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var userMarineLifeCatalog: [UserMarineLife] = []
    @State private var diveSiteCatalog: [DiveSite] = []
    @State private var hasLoadedCatalogs = false
    @State private var didScheduleEmptyCatalogRetry = false

    @State private var path: [FieldGuideRoute] = []
    @State private var fieldGuideHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var isFieldGuideHeaderCollapsed = false
    @State private var listScrollToTopNonce = 0
    @State private var catalogSnapshots: [MarineLifeCatalogSnapshot] = []
    @State private var categorySummaries: [FieldGuideCatalogIndex.CategorySummary] = []
    @State private var subcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex = [:]
    @State private var showsAddSpeciesSheet = false

    @Environment(RootTabSelectionStore.self) private var rootTabSelection

    private let ownerProfileID: UUID?

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
    }

    private var isFieldGuideTabSelected: Bool {
        RootTabSelectionPresentation.isSelected(.fieldGuide, selected: rootTabSelection.selected)
    }

    private var showsFieldGuideRootTabBar: Bool {
        FieldGuideNavigationPresentation.showsRootTabBar(
            for: fieldGuideTabBarVisibilityContext
        )
    }

    private var fieldGuideTabBarVisibilityContext: FieldGuideNavigationPresentation.TabBarVisibilityContext {
        switch path.last {
        case nil:
            return .hub
        case .category:
            return .categoryBrowse
        case .subcategory:
            return .subcategoryBrowse
        case .speciesDetail, .diveDetail, .diveSite:
            return .pushedDetail
        }
    }

    private var resolvedCatalogSnapshots: [MarineLifeCatalogSnapshot] {
        if catalogSnapshots.isEmpty, !marineLifeCatalog.isEmpty {
            return marineLifeCatalog.map(\.fieldGuideCatalogSnapshot)
        }
        return catalogSnapshots
    }

    private var resolvedCategorySummaries: [FieldGuideCatalogIndex.CategorySummary] {
        if categorySummaries.isEmpty, !resolvedCatalogSnapshots.isEmpty {
            return FieldGuideCatalogIndex.summaries(for: resolvedCatalogSnapshots)
        }
        return categorySummaries
    }

    private var resolvedSubcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex {
        if subcategorySpeciesIndex.isEmpty, !resolvedCatalogSnapshots.isEmpty {
            return FieldGuideCatalogIndex.subcategorySpeciesIndex(for: resolvedCatalogSnapshots)
        }
        return subcategorySpeciesIndex
    }

    private var showsFieldGuideHubChrome: Bool {
        path.isEmpty
    }

    /// Bubbles stay mounted for hub + category/subcategory browse (not opaque detail pushes).
    private var showsFieldGuideBubbleBackground: Bool {
        switch path.last {
        case nil, .category, .subcategory:
            return true
        case .speciesDetail, .diveDetail, .diveSite:
            return false
        }
    }

    private var showsTopChromeScrim: Bool {
        showsFieldGuideHubChrome
    }

    var body: some View {
        // One tab-level bubble layer — avoids stacked frozen TimelineViews on push.
        ZStack {
            if showsFieldGuideBubbleBackground, !GoDiveUITestConfiguration.isActive {
                WaterBubbleBackground(
                    animationPaused: RootTabSelectionPresentation.shouldPauseBubbles(
                        for: .fieldGuide,
                        selected: rootTabSelection.selected
                    ),
                    diagnosticsLabel: "FieldGuide"
                )
            }

            NavigationStack(path: $path) {
                AppHeaderlessPage(showsScreenBackgroundGradient: false) {
                    GeometryReader { proxy in
                        let listTopInset = proxy.safeAreaInsets.top + fieldGuideHeaderClearance
                        let listBottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

                        ZStack(alignment: .top) {
                            sectionContent(
                                topInset: listTopInset,
                                bottomInset: listBottomInset,
                                safeAreaTop: proxy.safeAreaInsets.top
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if showsTopChromeScrim {
                                LogbookTopChromeScrim(
                                    topObstructionHeight: listTopInset,
                                    featherHeight: CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                                )
                                    .padding(.top, -proxy.safeAreaInsets.top)
                                    .ignoresSafeArea(edges: .top)
                                    .allowsHitTesting(false)
                                    .zIndex(0.5)
                            }

                            if showsFieldGuideHubChrome {
                                FieldGuideTopChrome(
                                    isCollapsed: isFieldGuideHeaderCollapsed,
                                    statusBarSafeAreaTop: proxy.safeAreaInsets.top,
                                    onAddSpecies: { showsAddSpeciesSheet = true }
                                )
                                .zIndex(1)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                    }
                    .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                        if height > 0 { fieldGuideHeaderClearance = height }
                    }
                }
                .containerBackground(.clear, for: .navigation)
                .toolbar(.hidden, for: .navigationBar)
                .restoresRootTabBarWhenStackIsEmpty(showsFieldGuideRootTabBar)
                .coalescesNavigationStackPathDuplicates($path)
                .animation(nil, value: path.count)
                .navigationDestination(for: FieldGuideRoute.self) { route in
                    switch route {
                    case .category(let summary):
                        FieldGuideCategoryDetailView(
                            categoryID: summary.categoryID,
                            summary: summary,
                            catalogSnapshots: resolvedCatalogSnapshots,
                            subcategorySpeciesIndex: resolvedSubcategorySpeciesIndex,
                            unitSystem: diveDisplayUnitSystem,
                            onSelectSubcategory: { subcategoryID in
                                let payload = FieldGuideCatalogIndex.browsePayload(
                                    categoryID: summary.categoryID,
                                    subcategoryID: subcategoryID,
                                    speciesIndex: resolvedSubcategorySpeciesIndex
                                )
                                pushFieldGuide(.subcategory(payload))
                            },
                            onSelectSpecies: { uuid in
                                pushFieldGuide(.speciesDetail(uuid))
                            },
                            onAddSpecies: { showsAddSpeciesSheet = true }
                        )
                    case .subcategory(let payload):
                        FieldGuideSubcategorySpeciesView(
                            payload: payload,
                            unitSystem: diveDisplayUnitSystem,
                            catalogSnapshots: resolvedCatalogSnapshots,
                            onSelectSpecies: { uuid in
                                pushFieldGuide(.speciesDetail(uuid))
                            },
                            onAddSpecies: { showsAddSpeciesSheet = true }
                        )
                    case .speciesDetail(let marineLifeUUID):
                        if let species = marineLifeCatalog.first(where: { $0.uuid == marineLifeUUID }) {
                            FieldGuideMarineLifeDetailView(
                                species: species,
                                ownerProfileID: accountSession.currentProfile?.id
                            ) { activityID in
                                pushFieldGuide(.diveDetail(activityID))
                            }
                        } else if let species = userMarineLifeCatalog.first(where: { $0.uuid == marineLifeUUID }) {
                            FieldGuideMarineLifeDetailView(
                                species: species,
                                ownerProfileID: accountSession.currentProfile?.id
                            ) { activityID in
                                pushFieldGuide(.diveDetail(activityID))
                            }
                        } else {
                            missingSpeciesPlaceholder
                        }
                    case .diveDetail(let id):
                        OwnerDiveActivityDestinationView(activityID: id) {
                            path.removeAll {
                                if case .diveDetail(let routeID) = $0 { return routeID == id }
                                return false
                            }
                        }
                    case .diveSite(let siteID):
                        ExploreDiveSiteDetailHost(
                            siteID: siteID,
                            ownerProfileID: accountSession.currentProfile?.id,
                            onOpenDive: { pushFieldGuide(.diveDetail($0)) }
                        )
                    }
                }
            }
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            pushFieldGuide(.diveSite(siteID))
        }
        .environment(\.openCatalogMarineLifeDetail) { marineLifeUUID in
            pushFieldGuide(.speciesDetail(marineLifeUUID))
        }
        .onChange(of: path) { oldPath, newPath in
            DiveActivityOverviewUIStatePresentation.discardSessionsLeavingStack(
                previousDiveIDs: fieldGuideDiveActivityIDs(in: oldPath),
                currentDiveIDs: fieldGuideDiveActivityIDs(in: newPath)
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: ActivityDeleteSuccessPresentation.didDeleteNotification
            )
        ) { notification in
            guard let activityID = ActivityDeleteSuccessPresentation.activityID(from: notification) else {
                return
            }
            path.removeAll {
                if case .diveDetail(let id) = $0 { return id == activityID }
                return false
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
        .rootTabReselectObserver(notification: .fieldGuideTabReselected)
        .onReceive(NotificationCenter.default.publisher(for: .fieldGuideTabReselected)) { _ in
            handleFieldGuideTabReselect()
        }
        // Idle bind waits for Home chrome + quiet window; opening Field Guide binds now.
        .task {
            CatalogTabLoadDiagnostics.note(
                "fieldGuide.task wait selected=\(isFieldGuideTabSelected) chrome=\(accountSession.isHomeLaunchChromeReady) hasLoaded=\(hasLoadedCatalogs)"
            )
            await LazyRootTabPresentation.waitUntilCatalogBindAllowed(
                isTabSelected: { isFieldGuideTabSelected },
                isHomeLaunchChromeReady: { accountSession.isHomeLaunchChromeReady }
            )
            guard !Task.isCancelled else { return }
            CatalogTabLoadDiagnostics.note(
                "fieldGuide.task bind selected=\(isFieldGuideTabSelected) chrome=\(accountSession.isHomeLaunchChromeReady)"
            )
            await reloadFieldGuideCatalogsIfNeeded()
        }
        .onChange(of: marineLifeCatalog.count) { _, _ in
            syncCatalogCache()
        }
        .sheet(isPresented: $showsAddSpeciesSheet) {
            FieldGuideMarineLifeAddSheet { marineLifeUUID in
                handleAddedSpecies(marineLifeUUID)
            }
        }
    }

    private func handleAddedSpecies(_ marineLifeUUID: String) {
        Task {
            await reloadFieldGuideCatalogsIfNeeded(force: true)
            pushFieldGuide(.speciesDetail(marineLifeUUID))
        }
    }

    private func reloadFieldGuideCatalogsIfNeeded(force: Bool = false) async {
        let shouldFetch = LazyRootTabPresentation.shouldFetchCatalog(
            hasLoadedCatalog: hasLoadedCatalogs,
            force: force
        )
        CatalogTabLoadDiagnostics.note(
            "fieldGuide.reload gate shouldFetch=\(shouldFetch) force=\(force) hasLoaded=\(hasLoadedCatalogs) marine=\(marineLifeCatalog.count)"
        )
        guard shouldFetch else { return }
        CatalogTabLoadDiagnostics.note("fieldGuide.reload.start")
        let container = modelContext.container
        async let marineLifeIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
        async let diveSiteIDs = DiveSiteCatalogLoader.fetchSortedPersistentIDs(container: container)
        let loadedMarineLifeIDs = await marineLifeIDs
        let loadedDiveSiteIDs = await diveSiteIDs
        CatalogTabLoadDiagnostics.note(
            "fieldGuide.reload.ids marineIDs=\(loadedMarineLifeIDs.count) diveSiteIDs=\(loadedDiveSiteIDs.count) cancelled=\(Task.isCancelled)"
        )
        // Do not wipe a good catalog if this bind was cancelled mid-flight.
        guard !Task.isCancelled else {
            CatalogTabLoadDiagnostics.note("fieldGuide.reload.cancelled after ids")
            return
        }
        marineLifeCatalog = MarineLifeCatalogLoader.bindModels(
            persistentIDs: loadedMarineLifeIDs,
            modelContext: modelContext
        )
        userMarineLifeCatalog = (try? modelContext.fetch(
            FetchDescriptor<UserMarineLife>(sortBy: [SortDescriptor(\.commonName)])
        )) ?? []
        diveSiteCatalog = DiveSiteCatalogLoader.bindModels(
            persistentIDs: loadedDiveSiteIDs,
            modelContext: modelContext
        )
        let storeMarineCount = (try? modelContext.fetchCount(FetchDescriptor<MarineLife>())) ?? -1
        hasLoadedCatalogs = true
        CatalogTabLoadDiagnostics.note(
            "fieldGuide.reload.done boundMarine=\(marineLifeCatalog.count) storeMarine=\(storeMarineCount) userMarine=\(userMarineLifeCatalog.count) diveSites=\(diveSiteCatalog.count) hasLoaded=true"
        )
        syncCatalogCache()
        scheduleEmptyCatalogRetryIfNeeded()
    }

    /// Launch marine-life seed may finish after the first empty bind — one catch-up only.
    private func scheduleEmptyCatalogRetryIfNeeded() {
        guard hasLoadedCatalogs, marineLifeCatalog.isEmpty, !didScheduleEmptyCatalogRetry else { return }
        didScheduleEmptyCatalogRetry = true
        CatalogTabLoadDiagnostics.note("fieldGuide.emptyRetry.scheduled")
        Task {
            try? await Task.sleep(
                nanoseconds: LazyRootTabPresentation.emptyCatalogRetryNanoseconds
            )
            guard !Task.isCancelled else {
                CatalogTabLoadDiagnostics.note("fieldGuide.emptyRetry.cancelled")
                return
            }
            CatalogTabLoadDiagnostics.note("fieldGuide.emptyRetry.fire")
            await reloadFieldGuideCatalogsIfNeeded(force: true)
        }
    }

    private func syncCatalogCache() {
        let nextSnapshots = (try? MarineLifeSpeciesResolver.allCatalogSnapshots(modelContext: modelContext))
            ?? (marineLifeCatalog.map(\.fieldGuideCatalogSnapshot)
                + userMarineLifeCatalog.map(\.fieldGuideCatalogSnapshot))
        guard nextSnapshots != catalogSnapshots else { return }
        catalogSnapshots = nextSnapshots
        categorySummaries = FieldGuideCatalogIndex.summaries(for: nextSnapshots)
        subcategorySpeciesIndex = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: nextSnapshots)
        CatalogTabLoadDiagnostics.note(
            "fieldGuide.cache synced snapshots=\(nextSnapshots.count) categories=\(categorySummaries.count)"
        )
    }

    @ViewBuilder
    private func sectionContent(topInset: CGFloat, bottomInset: CGFloat, safeAreaTop: CGFloat) -> some View {
        fieldGuideCatalogListContent(
            topInset: topInset,
            bottomInset: bottomInset,
            safeAreaTop: safeAreaTop
        )
    }

    private func fieldGuideDiveActivityIDs(in path: [FieldGuideRoute]) -> Set<UUID> {
        Set(path.compactMap { route in
            if case .diveDetail(let id) = route { return id }
            return nil
        })
    }

    private func handleFieldGuideTabReselect() {
        path.removeAll()
        isFieldGuideHeaderCollapsed = false
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    private func handleFieldGuideHubScrollOffset(_ offset: CGFloat) {
        isFieldGuideHeaderCollapsed = CollapsibleInlineTitleHeaderPresentation
            .isCollapsed(forScrollOffset: offset)
    }

    private var missingSpeciesPlaceholder: some View {
        Text("This species is no longer in the catalog.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private var missingDiveSitePlaceholder: some View {
        Text("This dive site is no longer in the catalog.")
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    @ViewBuilder
    private func fieldGuideCatalogListContent(
        topInset: CGFloat,
        bottomInset: CGFloat,
        safeAreaTop: CGFloat
    ) -> some View {
        if !hasLoadedCatalogs, marineLifeCatalog.isEmpty {
            FieldGuideCatalogEmptyState()
                .padding(.top, topInset)
                .onAppear {
                    CatalogTabLoadDiagnostics.note(
                        "fieldGuide.ui LOADING hasLoaded=\(hasLoadedCatalogs) marine=\(marineLifeCatalog.count) categories=\(resolvedCategorySummaries.count)"
                    )
                }
        } else {
            FieldGuideCatalogHubView(
                summaries: resolvedCategorySummaries,
                topChromeInset: topInset,
                bottomChromeInset: bottomInset,
                statusBarSafeAreaTop: safeAreaTop,
                scrollToTopNonce: listScrollToTopNonce,
                onScrollOffsetChange: handleFieldGuideHubScrollOffset
            ) { summary in
                pushFieldGuide(.category(summary))
            }
            .equatable()
            .onAppear {
                CatalogTabLoadDiagnostics.note(
                    "fieldGuide.ui HUB hasLoaded=\(hasLoadedCatalogs) marine=\(marineLifeCatalog.count) categories=\(resolvedCategorySummaries.count)"
                )
            }
        }
    }

    private func pushFieldGuide(_ route: FieldGuideRoute) {
        NavigationStackPushCoalescing.append(route, to: &path)
    }
}

// MARK: - Empty states

private struct FieldGuideCatalogEmptyState: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            AppComingSoonPlaceholder(
                systemImage: "leaf",
                message: "Species catalog is loading. Check back shortly."
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

#Preview {
    FieldGuideView(ownerProfileID: nil)
        .environment(AccountSession.shared)
        .environment(RootTabSelectionStore())
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
