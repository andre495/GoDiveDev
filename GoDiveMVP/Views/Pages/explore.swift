import SwiftData
import SwiftUI

struct ExploreView: View {
    @Environment(AccountSession.self) private var accountSession
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]
    @State private var path: [ExploreRoute] = []
    @State private var viewMode: ExploreViewMode = .map
    @State private var siteScope: ExploreSiteScope = .logbook
    @State private var mapFocusedSelection: ExploreMapSiteSelection?
    @State private var mapFocusRequest: ExploreCatalogMapFocusRequest?
    @State private var exploreTopChromeHeight: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var listScrollToTopNonce = 0
    @State private var scopeCache = ExploreSiteScopeCache.Snapshot.empty
    @State private var displayedPlottableSites: [ExploreCatalogMapPresentation.PlottedSite] = []
    @State private var displayedPlottableSignature = ""
    @State private var displayedListRows: [ExploreDiveSiteRowDisplayData] = []

    private var displayedListSections: [ExploreDiveSiteListSection] {
        ExploreDiveSiteListPresentation.sections(from: displayedListRows)
    }
    @State private var scopeCacheRebuildTask: Task<Void, Never>?
    @State private var listRowsRefreshTask: Task<Void, Never>?
    @State private var showsAddDiveSiteSheet = false

    private var referenceCatalog: [DiveSiteReferenceSnapshot] {
        DiveSiteReferenceCatalog.bundledReference()
    }

    private var isExploreNavigationStackAtRoot: Bool {
        RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: path.count)
    }

    private var ownerDiveActivities: [DiveActivity] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return diveActivities.filter { $0.ownerProfileID == ownerID }
    }

    private var scopeCacheSyncToken: String {
        ExploreSiteScopeCache.syncToken(
            ownerProfileID: accountSession.currentProfile?.id,
            catalogSiteCount: diveSites.count,
            ownerActivitySiteLinkSignature: ExploreSiteScopeCache.ownerActivitySiteLinkSignature(
                ownerDiveActivities
            )
        )
    }

    private var mapPlottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        guard viewMode == .map, let mapFocusedSelection else { return displayedPlottableSites }
        return displayedPlottableSites.filter { $0.selection == mapFocusedSelection }
    }

    private var mapPlottableSignature: String {
        displayedPlottableSignature
    }

    private var showsSiteScopeToggle: Bool {
        scopeCache.showsSiteScopeToggle
    }

    private var showsScopedSiteContent: Bool {
        scopeCache.hasScopedContent(for: siteScope)
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                explorePageContent
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if showsSiteScopeToggle
                            && isExploreNavigationStackAtRoot
                        {
                            ExploreSiteScopeBottomChrome(selection: $siteScope)
                                .padding(
                                    .bottom,
                                    ExploreSiteScopeChromePresentation.paddingAboveTabBar()
                                )
                        }
                    }
            }
            .toolbar(.hidden, for: .navigationBar)
            .restoresRootTabBarWhenStackIsEmpty(isExploreNavigationStackAtRoot)
            .animation(nil, value: path.count)
            .navigationDestination(for: ExploreRoute.self, destination: exploreNavigationDestination)
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            path.append(.siteDetail(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .explore,
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
        .navigationInteractivePopGestureForHiddenNavBar()
        .rootTabReselectObserver(notification: .exploreTabReselected)
        .onReceive(NotificationCenter.default.publisher(for: .exploreTabReselected)) { _ in
            handleExploreTabReselect()
        }
        .onChange(of: viewMode) { _, mode in
            if mode == .list {
                clearMapSiteFocus()
            }
        }
        .onChange(of: siteScope) { _, _ in
            clearMapSiteFocus()
            applyScopePresentation()
            if viewMode == .list {
                RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
            }
        }
        .onChange(of: scopeCacheSyncToken) { _, _ in
            scheduleScopeCacheRebuild()
        }
        .onAppear {
            scheduleScopeCacheRebuild()
        }
        .onDisappear {
            scopeCacheRebuildTask?.cancel()
            scopeCacheRebuildTask = nil
            listRowsRefreshTask?.cancel()
            listRowsRefreshTask = nil
        }
        .sheet(isPresented: $showsAddDiveSiteSheet) {
            ExploreCatalogDiveSiteAddSheet { siteID in
                siteScope = .allSites
                path.append(.siteDetail(siteID))
            }
        }
    }

    private var explorePageContent: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + exploreTopChromeHeight
            let showsBottomSiteScopeToggle = showsSiteScopeToggle
                && isExploreNavigationStackAtRoot
            let bottomInset = proxy.safeAreaInsets.bottom
                + AppTheme.Spacing.md
                + (showsBottomSiteScopeToggle ? ExploreSiteScopeChromePresentation.listExtraBottomInset : 0)

            ZStack(alignment: .top) {
                if viewMode == .list, !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                }

                Group {
                    switch viewMode {
                    case .map:
                        ExploreCatalogMapView(
                            sites: mapPlottableSites,
                            sitesChangeSignature: mapPlottableSignature,
                            siteScope: siteScope,
                            focusRequest: mapFocusRequest
                        ) { selection in
                            openExploreSiteSelection(selection)
                        }
                        .ignoresSafeArea()
                    case .list:
                        exploreSiteList(topInset: topInset, bottomInset: bottomInset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewMode == .list, showsScopedSiteContent {
                    LogbookTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -proxy.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)
                }

                if viewMode == .map {
                    ExploreMapTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -proxy.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)
                }

                ExploreTopChrome(
                    viewMode: $viewMode,
                    statusBarSafeAreaTop: proxy.safeAreaInsets.top,
                    onAddDiveSite: { showsAddDiveSiteSheet = true }
                )
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea(edges: .bottom)
        }
        .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
            if height > 0 { exploreTopChromeHeight = height }
        }
    }

    @ViewBuilder
    private func exploreNavigationDestination(for route: ExploreRoute) -> some View {
        switch route {
        case .tripPlanner:
            TripPlannerView()
        case .tripDetail(let tripID):
            TripDetailStackNavigationPresentation.tripDetailDestination(tripID: tripID)
        case .tripDetailMedia(let tripID, let mediaID):
            TripDetailStackNavigationPresentation.tripDetailDestination(
                tripID: tripID,
                initialContentPage: .media,
                initialSelectedMediaID: mediaID
            )
        case .siteDetail(let siteID):
            if let site = diveSites.first(where: { $0.id == siteID }) {
                ExploreDiveSiteDetailView(
                    site: site,
                    ownerProfileID: accountSession.currentProfile?.id,
                    onOpenDive: { path.append(.diveDetail($0)) }
                )
            } else {
                Text("This dive site is no longer in the catalog.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .referenceSiteDetail(let referenceID):
            if let snapshot = referenceCatalog.first(where: { $0.id == referenceID }) {
                ExploreReferenceSiteDetailView(snapshot: snapshot)
            } else {
                Text("This dive site is no longer in the reference catalog.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .speciesDetail(let marineLifeUUID):
            if let species = marineLifeCatalog.first(where: { $0.uuid == marineLifeUUID }) {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: accountSession.currentProfile?.id
                ) { activityID in
                    path.append(.diveDetail(activityID))
                }
            } else {
                Text("This species is no longer in the catalog.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .diveDetail(let id):
            if let activity = ownerDiveActivities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                Text("This dive is no longer in your log.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        }
    }

    private func openExploreSiteSelection(_ selection: ExploreMapSiteSelection) {
        switch selection {
        case .catalog(let siteID):
            path.append(.siteDetail(siteID))
        case .reference(let referenceID):
            path.append(.referenceSiteDetail(referenceID))
        }
    }

    private func openExploreSiteRow(_ row: ExploreDiveSiteRowDisplayData) {
        openExploreSiteSelection(ExploreSiteScopePresentation.rowSelection(for: row))
    }

    private func clearMapSiteFocus() {
        mapFocusedSelection = nil
        mapFocusRequest = nil
    }

    private func handleExploreTabReselect() {
        path.removeAll()
        guard viewMode == .list else { return }
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    @ViewBuilder
    private func exploreSiteList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if !showsScopedSiteContent {
            exploreSiteListEmptyState
                .padding(.top, topInset)
                .padding(.horizontal, AppTheme.Spacing.lg)
        } else {
            List {
                Color.clear
                    .frame(height: topInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                ForEach(displayedListSections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            Button {
                                openExploreSiteRow(row)
                            } label: {
                                ExploreDiveSiteRow(data: row)
                                    .equatable()
                            }
                            .buttonStyle(.plain)
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
                            .accessibilityIdentifier(exploreSiteRowAccessibilityIdentifier(for: row))
                        }
                    } header: {
                        ExploreDiveSiteListSectionHeader(title: section.title)
                            .accessibilityIdentifier("Explore.SiteSection.\(section.title)")
                    }
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
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: [.top, .bottom])
            .listScrollToTopTrigger(nonce: listScrollToTopNonce)
        }
    }

    private func scheduleScopeCacheRebuild() {
        let profileID = accountSession.currentProfile?.id
        let catalog = diveSites
        let activities = ownerDiveActivities
        scopeCacheRebuildTask?.cancel()

        if scopeCache == .empty {
            scopeCache = ExploreSiteScopeCache.make(
                ownerProfileID: profileID,
                catalog: catalog,
                ownerActivities: activities
            )
            if let profileID {
                OwnerDiveIndexSessionCache.publish(
                    activities: activities,
                    ownerProfileID: profileID
                )
            }
            applyScopePresentation()
            return
        }

        scopeCacheRebuildTask = Task(priority: .userInitiated) {
            let snapshot = ExploreSiteScopeCache.make(
                ownerProfileID: profileID,
                catalog: catalog,
                ownerActivities: activities
            )
            guard !Task.isCancelled else { return }
            scopeCache = snapshot
            if let profileID {
                OwnerDiveIndexSessionCache.publish(
                    activities: activities,
                    ownerProfileID: profileID
                )
            }
            applyScopePresentation()
        }
    }

    private func applyScopePresentation() {
        displayedPlottableSites = scopeCache.plottableSites(for: siteScope)
        displayedPlottableSignature = scopeCache.plottableSignature(for: siteScope)
        scheduleDisplayedListRowsRefresh(immediate: true)
    }

    private func scheduleDisplayedListRowsRefresh(immediate: Bool = false) {
        listRowsRefreshTask?.cancel()
        let scope = siteScope
        let rows = scopeCache.listRows(for: scope)
        let debounceNanoseconds = immediate
            ? UInt64(0)
            : CatalogSearchPresentation.debounceNanoseconds

        listRowsRefreshTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let filteredRows = await Task.detached {
                ExploreSiteScopeCache.filteringListRows(rows, scope: scope, query: "")
            }.value

            guard !Task.isCancelled else { return }
            displayedListRows = filteredRows
        }
    }

    private func exploreSiteRowAccessibilityIdentifier(for row: ExploreDiveSiteRowDisplayData) -> String {
        if let referenceID = row.referenceID {
            return "Explore.ReferenceSiteRow.\(referenceID)"
        }
        return "Explore.SiteRow.\(row.id.uuidString)"
    }

    private var exploreSiteListEmptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: siteScope == .logbook ? "book.closed" : "globe.americas")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(siteScope == .logbook ? "No sites yet" : "No dive sites available")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(
                siteScope == .logbook
                    ? "Sites appear here after you log or import dives linked to a dive site. Switch to All Sites to browse the full catalog."
                    : "The bundled dive site catalog could not be loaded."
            )
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ExploreDiveSiteListSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabUnselected)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppTheme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ExploreView()
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
