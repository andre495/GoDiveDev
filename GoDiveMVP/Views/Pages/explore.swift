import SwiftData
import SwiftUI

struct ExploreView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    /// Snapshot from **`OwnerDiveActivitiesQueryBridge`** — only live while Explore is selected.
    @State private var ownerDiveActivities: [DiveActivity] = []
    @State private var latchedHasLoggedActivities = false
    @State private var hasReceivedLiveDiveSnapshot = false

    @State private var diveSites: [DiveSite] = []
    @State private var userDiveSites: [UserDiveSite] = []
    @State private var hasLoadedDiveSiteCatalog = false
    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var hasLoadedMarineLifeCatalog = false

    @State private var path: [ExploreRoute] = []
    @State private var viewMode: ExploreViewMode = .map
    @State private var siteScope: ExploreSiteScope = .allSites
    @State private var hasAppliedDefaultSiteScope = false
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
    @State private var appliedScopeCacheSyncToken: String?

    @Environment(RootTabSelectionStore.self) private var rootTabSelection

    private let ownerProfileID: UUID?

    /// Live tab selection via **`RootTabSelectionStore`** (not a stale `Tab` init `let`).
    private var isExploreTabSelected: Bool {
        RootTabSelectionPresentation.isSelected(.explore, selected: rootTabSelection.selected)
    }

    private var shouldMountLiveDiveQuery: Bool {
        RootTabOwnerDiveQueryPresentation.shouldMountLiveOwnerDiveQuery(
            isTabSelected: isExploreTabSelected
        )
    }

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
    }

    private var referenceCatalog: [DiveSiteReferenceSnapshot] {
        DiveSiteReferenceCatalog.bundledReference()
    }

    private var isExploreNavigationStackAtRoot: Bool {
        RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: path.count)
    }

    private var ownerDiveActivitiesForScope: [DiveActivity] {
        ownerDiveActivities
    }

    private var hasLoggedActivities: Bool {
        ExploreScopeCacheRebuildPresentation.hasLoggedActivities(
            shouldMountLiveDiveQuery: shouldMountLiveDiveQuery,
            hasReceivedLiveDiveSnapshot: hasReceivedLiveDiveSnapshot,
            liveActivityCount: ownerDiveActivitiesForScope.count,
            latchedHasLoggedActivities: latchedHasLoggedActivities
        )
    }

    private var scopeCacheSyncToken: String {
        ExploreSiteScopeCache.syncToken(
            ownerProfileID: accountSession.currentProfile?.id,
            catalogSiteCount: diveSites.count,
            userSiteCount: userDiveSites.count,
            ownerActivitySiteLinkSignature: ExploreSiteScopeCache.ownerActivitySiteLinkSignature(
                ownerDiveActivitiesForScope
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
            }
            .toolbar(.hidden, for: .navigationBar)
            .restoresRootTabBarWhenStackIsEmpty(isExploreNavigationStackAtRoot)
            .coalescesNavigationStackPathDuplicates($path)
            .animation(nil, value: path.count)
            .navigationDestination(for: ExploreRoute.self, destination: exploreNavigationDestination)
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            pushExplore(.siteDetail(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .explore,
                siteID: siteID,
                pathCountAfterAppend: path.count
            )
        }
        .environment(\.openCatalogMarineLifeDetail) { marineLifeUUID in
            pushExplore(.speciesDetail(marineLifeUUID))
        }
        .environment(\.openTripDetail) { tripID in
            pushExplore(.tripDetail(tripID))
        }
        .environment(\.openTripDetailMedia) { launch in
            pushExplore(.tripDetailMedia(tripID: launch.tripID, mediaID: launch.mediaID))
        }
        .onChange(of: path) { oldPath, newPath in
            DiveActivityOverviewUIStatePresentation.discardSessionsLeavingStack(
                previousDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inExplorePath: oldPath
                ),
                currentDiveIDs: DiveActivityOverviewUIStatePresentation.diveActivityIDs(
                    inExplorePath: newPath
                )
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
            path = ActivityDeleteSuccessPresentation.explorePathByRemovingActivity(
                path,
                activityID: activityID
            )
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
            guard isExploreTabSelected else { return }
            scheduleScopeCacheRebuild()
        }
        .onChange(of: hasLoggedActivities) { _, hasActivities in
            guard isExploreTabSelected else { return }
            applyPreferredSiteScope(hasLoggedActivities: hasActivities)
        }
        .onAppear {
            // Do not build the ~3k-site scope cache on main while Home is launching —
            // that path caused launch hangs. Seed only when Explore is selected.
            if isExploreTabSelected {
                primeLoggedActivityLatchFromKnownStateIfNeeded()
                applyDefaultSiteScopeIfNeeded()
                seedPinsFromSessionCacheIfNeeded()
                rebuildScopeCacheOnAppearIfNeeded()
            }
            Task { await loadDiveSiteCatalogIfNeeded() }
            warmMapsIfExploreSelected()
        }
        .onChange(of: rootTabSelection.selected) { _, tab in
            guard tab == .explore else { return }
            primeLoggedActivityLatchFromKnownStateIfNeeded()
            applyDefaultSiteScopeIfNeeded()
            warmMapsIfExploreSelected()
            // Sync seed from launch prewarm so the map mounts with pins (no empty flash).
            // Skipped when My Sites is the preferred default (avoids All Sites → My Sites jump).
            seedPinsFromSessionCacheIfNeeded()
            rebuildScopeCacheOnAppearIfNeeded()
        }
        .background {
            if shouldMountLiveDiveQuery {
                OwnerDiveActivitiesQueryBridge(ownerProfileID: ownerProfileID) { activities in
                    applyOwnerDiveActivitiesFromBridge(activities)
                }
            }
        }
        .task(id: ownerProfileID) {
            async let loadedMarineLife = loadMarineLifeCatalogIfNeeded()
            async let loadedDiveSites = loadDiveSiteCatalogIfNeeded()
            _ = await (loadedMarineLife, loadedDiveSites)
        }
        .onDisappear {
            // Do **not** cancel `scopeCacheRebuildTask` here — TabView / NavigationStack can
            // fire a spurious disappear while Explore is still selected, which previously
            // aborted the detached ODM pin rebuild and left the map blank.
            listRowsRefreshTask?.cancel()
            listRowsRefreshTask = nil
        }
        .sheet(isPresented: $showsAddDiveSiteSheet) {
            ExploreCatalogDiveSiteAddSheet { siteID in
                siteScope = .allSites
                pushExplore(.siteDetail(siteID))
            }
        }
    }

    private var explorePageContent: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + exploreTopChromeHeight
            let bottomInset = proxy.safeAreaInsets.bottom + AppTheme.Spacing.md

            ZStack(alignment: .top) {
                if viewMode == .list, !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground(diagnosticsLabel: "Explore")
                }

                Group {
                    switch viewMode {
                    case .map:
                        // Mount the map engine only once pins exist so makeUIView gets a real
                        // site set + camera fit — avoids empty world map then recenter.
                        if displayedPlottableSites.isEmpty {
                            ExploreCatalogMapLoadingPlaceholder()
                                .ignoresSafeArea()
                        } else {
                            ExploreCatalogMapView(
                                sites: mapPlottableSites,
                                sitesChangeSignature: mapPlottableSignature,
                                siteScope: siteScope,
                                focusRequest: mapFocusRequest
                            ) { selection in
                                openExploreSiteSelection(selection)
                            }
                            .ignoresSafeArea()
                        }
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

                // Absorbs map / list pans in the chrome band so My Sites | All Sites stays tappable.
                Color.clear
                    .frame(height: topInset)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                    .zIndex(0.75)

                ExploreTopChrome(
                    viewMode: $viewMode,
                    siteScope: $siteScope,
                    showsSiteScopeToggle: showsSiteScopeToggle && isExploreNavigationStackAtRoot,
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
            ExploreDiveSiteDetailHost(
                siteID: siteID,
                ownerProfileID: accountSession.currentProfile?.id,
                onOpenDive: { pushExplore(.diveDetail($0)) }
            )
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
                    pushExplore(.diveDetail(activityID))
                }
            } else {
                Text("This species is no longer in the catalog.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .diveDetail(let id):
            OwnerDiveActivityDestinationView(activityID: id) {
                path = ActivityDeleteSuccessPresentation.explorePathByRemovingActivity(
                    path,
                    activityID: id
                )
            }
        }
    }

    private func openExploreSiteSelection(_ selection: ExploreMapSiteSelection) {
        switch selection {
        case .catalog(let siteID):
            pushExplore(.siteDetail(siteID))
        case .reference(let referenceID):
            pushExplore(.referenceSiteDetail(referenceID))
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

    private var prefersLogbookDefault: Bool {
        ExploreSiteScopePresentation.defaultScope(hasLoggedActivities: hasLoggedActivities) == .logbook
    }

    /// Home (or a one-row fetch) often knows about activities before the Explore dive bridge mounts.
    private func primeLoggedActivityLatchFromKnownStateIfNeeded() {
        guard !latchedHasLoggedActivities else {
            if !hasAppliedDefaultSiteScope, prefersLogbookDefault, siteScope != .logbook {
                siteScope = .logbook
            }
            return
        }
        let profileID = accountSession.currentProfile?.id ?? ownerProfileID
        if let profileID,
           let index = OwnerDiveIndexSessionCache.resolve(ownerProfileID: profileID),
           !index.numberingRows.isEmpty {
            latchedHasLoggedActivities = true
            if !hasAppliedDefaultSiteScope {
                siteScope = .logbook
            }
            ExplorePinsDiagnostics.note("primed My Sites from OwnerDiveIndexSessionCache")
            return
        }
        guard let profileID else { return }
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { $0.ownerProfileID == profileID }
        )
        descriptor.fetchLimit = 1
        if let rows = try? modelContext.fetch(descriptor), !rows.isEmpty {
            latchedHasLoggedActivities = true
            if !hasAppliedDefaultSiteScope {
                siteScope = .logbook
            }
            ExplorePinsDiagnostics.note("primed My Sites from DiveActivity fetchLimit=1")
        }
    }

    private func applyDefaultSiteScopeIfNeeded() {
        // Prefer My Sites as soon as we know activities exist (latch / Home index) — do not
        // wait for the live bridge if that would flash All Sites first.
        if !hasAppliedDefaultSiteScope, prefersLogbookDefault, siteScope != .logbook {
            siteScope = .logbook
        }
        guard ExploreScopeCacheRebuildPresentation.shouldApplyDefaultSiteScope(
            hasAppliedDefaultSiteScope: hasAppliedDefaultSiteScope,
            hasReceivedLiveDiveSnapshot: hasReceivedLiveDiveSnapshot || latchedHasLoggedActivities
        ) else { return }
        applyPreferredSiteScope(hasLoggedActivities: hasLoggedActivities)
    }

    /// Applies All Sites / My Sites preference without blanking the map when My Sites pins
    /// are not ready yet (defers the toggle until the activity-aware cache has logbook sites).
    private func applyPreferredSiteScope(hasLoggedActivities: Bool) {
        let desired = ExploreSiteScopePresentation.defaultScope(
            hasLoggedActivities: hasLoggedActivities
        )
        if ExploreScopeCacheRebuildPresentation.shouldDeferDefaultLogbookScope(
            desiredScope: desired,
            logbookPlottableCount: scopeCache.plottableSites(for: .logbook).count
        ) {
            // Still show My Sites on the toggle while pins catch up.
            if desired == .logbook, siteScope != .logbook {
                siteScope = .logbook
            }
            return
        }
        hasAppliedDefaultSiteScope = true
        guard siteScope != desired else { return }
        siteScope = desired
        applyScopePresentation()
    }

    /// Instant All Sites paint from launch prewarm — only when All Sites is the preferred default.
    @discardableResult
    private func seedPinsFromSessionCacheIfNeeded() -> Bool {
        guard displayedPlottableSites.isEmpty else { return true }
        if scopeCache != .empty {
            applyScopePresentation()
            if !displayedPlottableSites.isEmpty { return true }
        }
        guard let warm = ExploreSiteScopeSessionCache.cachedReferenceSnapshot() else {
            return false
        }
        scopeCache = warm
        guard ExploreScopeCacheRebuildPresentation.shouldPaintAllSitesSessionSeed(
            prefersLogbookDefault: prefersLogbookDefault
        ) else {
            ExplorePinsDiagnostics.note(
                "session cache held for My Sites default allSites=\(warm.allSitesPlottableSites.count)"
            )
            return false
        }
        applyScopePresentation()
        ExplorePinsDiagnostics.note(
            "seed from session cache allSites=\(warm.allSitesPlottableSites.count) display=\(displayedPlottableSites.count)"
        )
        return !displayedPlottableSites.isEmpty
    }

    private func rebuildScopeCacheOnAppearIfNeeded() {
        // Blank map is always a rebuild — do not trust a stale applied sync token while
        // `displayedPlottableSites` is empty (idle-tab regressions left the map at sites=0).
        if displayedPlottableSites.isEmpty {
            if seedPinsFromSessionCacheIfNeeded() {
                // Still refresh logbook/visited tint in the background.
                scheduleScopeCacheRebuild()
                return
            }
            scheduleScopeCacheRebuild()
            return
        }
        let token = scopeCacheSyncToken
        guard ExploreScopeCacheAppearPresentation.shouldRebuildScopeCacheOnAppear(
            isCacheEmpty: scopeCache == .empty,
            appliedSyncToken: appliedScopeCacheSyncToken,
            currentSyncToken: token
        ) else {
            ExplorePinsDiagnostics.note(
                "appear rebuild skipped cacheEmpty=\(scopeCache == .empty) display=\(displayedPlottableSites.count)"
            )
            return
        }
        scheduleScopeCacheRebuild()
    }

    private func applyOwnerDiveActivitiesFromBridge(_ activities: [DiveActivity]) {
        ownerDiveActivities = activities
        // Never clear the latch on a transient empty delivery — that re-defaults to All Sites.
        if !activities.isEmpty {
            latchedHasLoggedActivities = true
        }
        let wasFirstSnapshot = !hasReceivedLiveDiveSnapshot
        hasReceivedLiveDiveSnapshot = true
        if RootTabOwnerDiveQueryPresentation.shouldPublishOwnerDiveIndex(
            isTabSelected: isExploreTabSelected,
            activityCount: activities.count
        ), let profileID = accountSession.currentProfile?.id ?? ownerProfileID {
            OwnerDiveIndexSessionCache.publish(
                activities: activities,
                ownerProfileID: profileID
            )
        }
        if wasFirstSnapshot {
            scheduleScopeCacheRebuild()
            applyDefaultSiteScopeIfNeeded()
        } else {
            applyPreferredSiteScope(hasLoggedActivities: !activities.isEmpty)
        }
    }

    /// Always builds off the main actor — synchronous `make()` of ~3k ODM sites on main
    /// can watchdog-kill launch when Explore mounts early.
    private func scheduleScopeCacheRebuild() {
        guard isExploreTabSelected else {
            ExplorePinsDiagnostics.note("rebuild skipped — Explore not selected")
            return
        }
        let profileID = accountSession.currentProfile?.id
        let catalog = diveSites
        let userSites = userDiveSites
        let activities = ownerDiveActivitiesForScope
        let logbookSiteIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: activities,
            ownerProfileID: profileID
        )
        let syncToken = scopeCacheSyncToken
        scopeCacheRebuildTask?.cancel()

        if scopeCache == .empty {
            ExplorePinsDiagnostics.resetSession()
        }
        ExplorePinsDiagnostics.note(
            "rebuild start cacheEmpty=\(scopeCache == .empty) catalog=\(catalog.count) userSites=\(userSites.count) logbookIDs=\(logbookSiteIDs.count)"
        )

        scopeCacheRebuildTask = Task(priority: .userInitiated) {
            // Reference-only off-main (Sendable). SwiftData catalog/user sites stay on main.
            let referenceSnapshot = await Task.detached(priority: .userInitiated) {
                ExploreSiteScopeCache.make(
                    catalog: [],
                    userSites: [],
                    logbookSiteIDs: logbookSiteIDs
                )
            }.value
            guard !Task.isCancelled else {
                ExplorePinsDiagnostics.note("rebuild cancelled after reference")
                return
            }
            scopeCache = referenceSnapshot
            ExploreSiteScopeSessionCache.storeReferenceSnapshot(referenceSnapshot)
            applyScopePresentation()
            ExplorePinsDiagnostics.note(
                "rebuild reference allSites=\(referenceSnapshot.allSitesPlottableSites.count) display=\(displayedPlottableSites.count)"
            )

            let fullSnapshot = ExploreSiteScopeCache.make(
                catalog: catalog,
                userSites: userSites,
                logbookSiteIDs: logbookSiteIDs
            )
            guard !Task.isCancelled else {
                ExplorePinsDiagnostics.note("rebuild cancelled before full apply")
                return
            }
            scopeCache = fullSnapshot
            ExploreSiteScopeSessionCache.storeReferenceSnapshot(fullSnapshot)
            appliedScopeCacheSyncToken = syncToken
            if let profileID {
                OwnerDiveIndexSessionCache.publish(
                    activities: activities,
                    ownerProfileID: profileID
                )
            }
            applyScopePresentation()
            applyDefaultSiteScopeIfNeeded()
            ExplorePinsDiagnostics.note(
                "rebuild done allSites=\(fullSnapshot.allSitesPlottableSites.count) logbook=\(fullSnapshot.logbookPlottableSites.count) display=\(displayedPlottableSites.count) scope=\(siteScope)"
            )
        }
    }

    private func applyScopePresentation() {
        // Never publish pins from an uninitialized cache (map wipe).
        guard ExploreScopeCacheRebuildPresentation.shouldApplyScopePresentation(
            isCacheEmpty: scopeCache == .empty
        ) else {
            ExplorePinsDiagnostics.note("apply skipped — cache empty")
            return
        }
        let scopedSites = scopeCache.plottableSites(for: siteScope)
        let decision = ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
            siteScope: siteScope,
            scopedSitesCount: scopedSites.count,
            allSitesCount: scopeCache.allSitesPlottableSites.count,
            currentlyDisplayingSites: !displayedPlottableSites.isEmpty,
            prefersLogbookDefault: prefersLogbookDefault
        )
        switch decision {
        case .keepWaitingForLogbook:
            ExplorePinsDiagnostics.note("apply waiting for My Sites pins")
            scheduleDisplayedListRowsRefresh(immediate: true)
            return
        case .keepCurrentDisplay:
            ExplorePinsDiagnostics.note(
                "apply keepCurrent scoped=0 all=\(scopeCache.allSitesPlottableSites.count)"
            )
            scheduleDisplayedListRowsRefresh(immediate: true)
            return
        case .useAllSitesFallback:
            guard ExploreScopeCacheRebuildPresentation.shouldFallbackToAllSitesWhileLogbookEmpty(
                prefersLogbookDefault: prefersLogbookDefault
            ) else {
                ExplorePinsDiagnostics.note("apply skip All Sites fallback — prefer My Sites")
                scheduleDisplayedListRowsRefresh(immediate: true)
                return
            }
            displayedPlottableSites = scopeCache.allSitesPlottableSites
            displayedPlottableSignature = scopeCache.allSitesPlottableSignature
            if siteScope != .allSites {
                siteScope = .allSites
            }
            ExplorePinsDiagnostics.note(
                "apply fallback allSites=\(displayedPlottableSites.count)"
            )
            scheduleDisplayedListRowsRefresh(immediate: true)
            return
        case .useScopedSites:
            break
        }
        displayedPlottableSites = scopedSites
        displayedPlottableSignature = scopeCache.plottableSignature(for: siteScope)
        if siteScope == .logbook, !scopedSites.isEmpty {
            hasAppliedDefaultSiteScope = true
        }
        ExplorePinsDiagnostics.note(
            "apply display=\(scopedSites.count) scope=\(siteScope)"
        )
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

    private func warmMapsIfExploreSelected() {
        guard isExploreTabSelected else { return }
        MapKitWarmup.warmUpIfNeeded()
        #if canImport(GoogleMaps)
        GoogleMapsWarmup.warmUpIfNeeded()
        #endif
    }

    private func loadMarineLifeCatalogIfNeeded() async {
        guard !hasLoadedMarineLifeCatalog || marineLifeCatalog.isEmpty else { return }
        marineLifeCatalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        guard !Task.isCancelled else { return }
        hasLoadedMarineLifeCatalog = true
    }

    private func loadDiveSiteCatalogIfNeeded() async {
        let shouldLoadCatalog = !hasLoadedDiveSiteCatalog || diveSites.isEmpty
        if shouldLoadCatalog {
            diveSites = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
        }
        // Always refresh user sites — launch hydrate / CloudKit import can insert after first paint.
        userDiveSites = (try? modelContext.fetch(
            FetchDescriptor<UserDiveSite>(sortBy: [SortDescriptor(\.siteName)])
        )) ?? []
        guard !Task.isCancelled else { return }
        hasLoadedDiveSiteCatalog = true
    }

    private func pushExplore(_ route: ExploreRoute) {
        NavigationStackPushCoalescing.append(route, to: &path)
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
    ExploreView(ownerProfileID: nil)
        .environment(RootTabSelectionStore())
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
