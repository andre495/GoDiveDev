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
    @State private var siteSearchQuery = ""
    @FocusState private var isSiteSearchFocused: Bool
    @State private var mapFocusedSelection: ExploreMapSiteSelection?
    @State private var mapFocusedSiteName: String?
    @State private var mapFocusRequest: ExploreCatalogMapFocusRequest?
    @State private var exploreTopChromeHeight: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var listScrollToTopNonce = 0

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

    private var logbookSiteIDs: Set<UUID> {
        ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: ownerDiveActivities,
            ownerProfileID: accountSession.currentProfile?.id
        )
    }

    private var scopedCatalogSites: [DiveSite] {
        ExploreSiteScopePresentation.logbookCatalogSites(
            catalog: diveSites,
            logbookSiteIDs: logbookSiteIDs
        )
    }

    private var siteListRows: [ExploreDiveSiteRowDisplayData] {
        ExploreSiteScopePresentation.catalogListRows(
            scope: siteScope,
            catalog: diveSites,
            logbookSiteIDs: logbookSiteIDs,
            reference: referenceCatalog,
            query: siteSearchQuery
        )
    }

    private var plottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        ExploreSiteScopePresentation.plottableSites(
            scope: siteScope,
            catalog: diveSites,
            logbookSiteIDs: logbookSiteIDs,
            reference: referenceCatalog
        )
    }

    private var mapPlottableSites: [ExploreCatalogMapPresentation.PlottedSite] {
        guard viewMode == .map, let mapFocusedSelection else { return plottableSites }
        return plottableSites.filter { $0.selection == mapFocusedSelection }
    }

    private var siteSearchSuggestions: [ExploreDiveSiteSearchSuggestion] {
        ExploreDiveSiteSearchPresentation.suggestions(
            scope: siteScope,
            catalog: diveSites,
            logbookSiteIDs: logbookSiteIDs,
            reference: referenceCatalog,
            plottableSites: plottableSites,
            query: siteSearchQuery
        )
    }

    private var showsMapSearchSuggestions: Bool {
        ExploreDiveSiteSearchPresentation.showsSuggestions(
            viewMode: viewMode,
            query: siteSearchQuery,
            mapFocusedSelection: mapFocusedSelection
        )
    }

    private var isFilteringSites: Bool {
        switch siteScope {
        case .logbook:
            ExploreDiveSiteListSearch.isFiltering(query: siteSearchQuery)
        case .allSites:
            ExploreReferenceSiteListSearch.isFiltering(query: siteSearchQuery)
        }
    }

    private var showsSiteSearch: Bool {
        showsScopedSiteContent
    }

    private var showsSiteScopeToggle: Bool {
        !referenceCatalog.isEmpty
    }

    private var showsScopedSiteContent: Bool {
        switch siteScope {
        case .logbook:
            !scopedCatalogSites.isEmpty
        case .allSites:
            !referenceCatalog.isEmpty
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                explorePageContent
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
            if mode != .list {
                dismissSiteSearchKeyboard()
            }
            if mode == .list {
                clearMapSiteSearch()
            }
        }
        .onChange(of: siteScope) { _, _ in
            siteSearchQuery = ""
            clearMapSiteSearch()
            dismissSiteSearchKeyboard()
            if viewMode == .list {
                RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
            }
        }
        .onChange(of: siteSearchQuery) { _, newQuery in
            guard mapFocusedSelection != nil else { return }
            let trimmedQuery = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFocusedName = mapFocusedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard trimmedQuery != trimmedFocusedName else { return }
            clearMapSiteSearch(keepingQuery: true)
        }
        .onChange(of: isSiteSearchFocused) { _, isFocused in
            if !isFocused {
                dismissSiteSearchKeyboard()
            }
        }
    }

    private var explorePageContent: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + exploreTopChromeHeight
            let bottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

            ZStack(alignment: .top) {
                if viewMode == .list, !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                }

                Group {
                    switch viewMode {
                    case .map:
                        ExploreCatalogMapView(
                            sites: mapPlottableSites,
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

                ExploreTopChrome(
                    viewMode: $viewMode,
                    siteScope: $siteScope,
                    siteSearchQuery: $siteSearchQuery,
                    isSiteSearchFocused: $isSiteSearchFocused,
                    showsSiteSearch: showsSiteSearch,
                    showsSiteScopeToggle: showsSiteScopeToggle,
                    siteSearchSuggestions: siteSearchSuggestions,
                    showsMapSearchSuggestions: showsMapSearchSuggestions,
                    statusBarSafeAreaTop: proxy.safeAreaInsets.top,
                    onOpenTripPlanner: { path.append(.tripPlanner) },
                    onSelectSiteSearchSuggestion: selectMapSiteSearchSuggestion,
                    onClearMapSiteSearch: { clearMapSiteSearch() }
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
                    ownerProfileID: accountSession.currentProfile?.id
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

    private func dismissSiteSearchKeyboard() {
        isSiteSearchFocused = false
    }

    private func selectMapSiteSearchSuggestion(_ suggestion: ExploreDiveSiteSearchSuggestion) {
        mapFocusedSiteName = suggestion.siteName
        mapFocusedSelection = suggestion.selection
        mapFocusRequest = ExploreCatalogMapFocusRequest(
            selection: suggestion.selection,
            coordinate: suggestion.coordinate,
            requestID: UUID()
        )
        siteSearchQuery = suggestion.siteName
        dismissSiteSearchKeyboard()
    }

    private func clearMapSiteSearch(keepingQuery: Bool = false) {
        mapFocusedSelection = nil
        mapFocusedSiteName = nil
        mapFocusRequest = nil
        if !keepingQuery {
            siteSearchQuery = ""
        }
    }

    private func handleExploreTabReselect() {
        path.removeAll()
        isSiteSearchFocused = false
        guard viewMode == .list else { return }
        RootTabListScrollSupport.scheduleScrollToTop { listScrollToTopNonce += 1 }
    }

    @ViewBuilder
    private func exploreSiteList(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        if !showsScopedSiteContent {
            exploreSiteListEmptyState
                .padding(.top, topInset)
                .padding(.horizontal, AppTheme.Spacing.lg)
        } else if siteListRows.isEmpty && isFilteringSites {
            CatalogSearchEmptyState(
                title: "No matching dive sites",
                message: "Try a different site name or place."
            )
            .padding(.top, topInset)
        } else {
            List {
                Color.clear
                    .frame(height: topInset)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                ForEach(siteListRows) { row in
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

            Text(siteScope == .logbook ? "No logbook sites yet" : "No dive sites available")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(
                siteScope == .logbook
                    ? "Sites appear here after you log or import dives linked to a dive site. Switch to All sites to browse the full catalog."
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

#Preview {
    ExploreView()
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
