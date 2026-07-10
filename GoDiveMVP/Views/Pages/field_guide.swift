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

    @Query private var ownerDiveActivities: [DiveActivity]

    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var diveSiteCatalog: [DiveSite] = []
    @State private var hasLoadedCatalogs = false

    @State private var path: [FieldGuideRoute] = []
    @State private var fieldGuideHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var isFieldGuideHeaderCollapsed = false
    @State private var listScrollToTopNonce = 0
    @State private var catalogSnapshots: [MarineLifeCatalogSnapshot] = []
    @State private var categorySummaries: [FieldGuideCatalogIndex.CategorySummary] = []
    @State private var subcategorySpeciesIndex: FieldGuideCatalogIndex.SubcategorySpeciesIndex = [:]
    @State private var showsAddSpeciesSheet = false

    private let ownerProfileID: UUID?

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

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

    private var isNavigatingCatalog: Bool {
        !path.isEmpty
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

    private var showsTopChromeScrim: Bool {
        showsFieldGuideHubChrome
    }

    private var ownerDiveActivitiesForNavigation: [DiveActivity] {
        ownerDiveActivities
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
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
            .toolbar(.hidden, for: .navigationBar)
            .restoresRootTabBarWhenStackIsEmpty(showsFieldGuideRootTabBar)
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
                            path.append(.subcategory(payload))
                        },
                        onSelectSpecies: { uuid in
                            path.append(.speciesDetail(uuid))
                        },
                        onAddSpecies: { showsAddSpeciesSheet = true }
                    )
                case .subcategory(let payload):
                    FieldGuideSubcategorySpeciesView(
                        payload: payload,
                        unitSystem: diveDisplayUnitSystem,
                        catalogSnapshots: resolvedCatalogSnapshots,
                        onSelectSpecies: { uuid in
                            path.append(.speciesDetail(uuid))
                        },
                        onAddSpecies: { showsAddSpeciesSheet = true }
                    )
                case .speciesDetail(let marineLifeUUID):
                    if let species = marineLifeCatalog.first(where: { $0.uuid == marineLifeUUID }) {
                        FieldGuideMarineLifeDetailView(
                            species: species,
                            ownerProfileID: accountSession.currentProfile?.id
                        ) { activityID in
                            path.append(.diveDetail(activityID))
                        }
                    } else {
                        missingSpeciesPlaceholder
                    }
                case .diveDetail(let id):
                    if let activity = ownerDiveActivitiesForNavigation.first(where: { $0.id == id }) {
                        ViewSingleActivity(activity: activity)
                    } else {
                        missingDivePlaceholder
                    }
                case .diveSite(let siteID):
                    if let site = diveSiteCatalog.first(where: { $0.id == siteID }) {
                        ExploreDiveSiteDetailView(
                            site: site,
                            ownerProfileID: accountSession.currentProfile?.id,
                            onOpenDive: { path.append(.diveDetail($0)) }
                        )
                    } else {
                        missingDiveSitePlaceholder
                    }
                }
            }
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            path.append(.diveSite(siteID))
        }
        .navigationInteractivePopGestureForHiddenNavBar()
        .rootTabReselectObserver(notification: .fieldGuideTabReselected)
        .onReceive(NotificationCenter.default.publisher(for: .fieldGuideTabReselected)) { _ in
            handleFieldGuideTabReselect()
        }
        .task(id: ownerProfileID) {
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
            path.append(.speciesDetail(marineLifeUUID))
        }
    }

    private func reloadFieldGuideCatalogsIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedCatalogs || marineLifeCatalog.isEmpty else { return }
        let container = modelContext.container
        async let marineLifeIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
        async let diveSiteIDs = DiveSiteCatalogLoader.fetchSortedPersistentIDs(container: container)
        marineLifeCatalog = MarineLifeCatalogLoader.bindModels(
            persistentIDs: await marineLifeIDs,
            modelContext: modelContext
        )
        diveSiteCatalog = DiveSiteCatalogLoader.bindModels(
            persistentIDs: await diveSiteIDs,
            modelContext: modelContext
        )
        guard !Task.isCancelled else { return }
        hasLoadedCatalogs = true
        syncCatalogCache()
    }

    private func syncCatalogCache() {
        let nextSnapshots = marineLifeCatalog.map(\.fieldGuideCatalogSnapshot)
        guard nextSnapshots != catalogSnapshots else { return }
        catalogSnapshots = nextSnapshots
        categorySummaries = FieldGuideCatalogIndex.summaries(for: nextSnapshots)
        subcategorySpeciesIndex = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: nextSnapshots)
    }

    @ViewBuilder
    private func sectionContent(topInset: CGFloat, bottomInset: CGFloat, safeAreaTop: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if !GoDiveUITestConfiguration.isActive {
                WaterBubbleBackground(animationPaused: isNavigatingCatalog)
            }

            fieldGuideCatalogListContent(
                topInset: topInset,
                bottomInset: bottomInset,
                safeAreaTop: safeAreaTop
            )
        }
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

    private var missingDivePlaceholder: some View {
        Text("This dive is no longer in your log.")
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
        } else {
            FieldGuideCatalogHubView(
                summaries: resolvedCategorySummaries,
                topChromeInset: topInset,
                bottomChromeInset: bottomInset,
                statusBarSafeAreaTop: safeAreaTop,
                scrollToTopNonce: listScrollToTopNonce,
                onScrollOffsetChange: handleFieldGuideHubScrollOffset
            ) { summary in
                path.append(.category(summary))
            }
            .equatable()
        }
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
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
