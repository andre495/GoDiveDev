import Combine
import SwiftData
import SwiftUI

struct LogOverviewView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isCelebrationShellPrewarmActive) private var isCelebrationShellPrewarmActive

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var ownerDiveBuddies: [DiveBuddy]

    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var diveSiteCatalog: [DiveSite] = []
    @State private var hasLoadedNavigationCatalogs = false

    private let ownerProfileID: UUID?

    @State private var path: [HomeRoute] = []
    @State private var carouselHighlights: [HomeMediaHighlight] = []
    @State private var homeAggregate = HomeOverviewAggregate.empty
    @State private var lastCarouselFingerprint = 0
    @State private var lastCarouselTagFingerprint = 0
    @State private var hasCarouselSessionWarmCompleted = false
    @State private var hasPerformedInitialHomeBuild = false
    @State private var homeOverviewRebuildGeneration = 0
    @State private var selfBuddyID: UUID?
    @State private var homeHeroInteractionOverlayActive = false
    @State private var frozenHomeRootViewportHeight: CGFloat?
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    private var buddyRosterFingerprint: Int {
        HomeBuddyRosterRefreshToken.fingerprint(
            buddies: ownerDiveBuddies.map {
                HomeBuddyRosterRefreshToken.BuddyRow(
                    id: $0.id,
                    displayName: $0.displayName,
                    profilePhoto: $0.profilePhoto
                )
            }
        )
    }

    private var isHomeNavigationStackAtRoot: Bool {
        path.isEmpty
    }

    private enum Layout {
        static let profileAvatarDiameter = BlueSheetTopChromePresentation.homeProfileAvatarDiameter
    }

    /// Sentinel owner id so **`@Query`** returns no rows when signed out (matches Logbook).
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

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
        _ownerDiveBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\DiveBuddy.displayName, order: .forward)]
        )
    }

    private var showsHomeBuddyLeaderboard: Bool {
        HomeBuddyLeaderboardPresentation.shouldShow(
            diveCount: homeAggregate.diveStatsInputs.count,
            entries: homeAggregate.buddyLeaderboard
        )
    }

    @ViewBuilder
    private func homeDashboard() -> some View {
        let seamInputs = HomeTabRootLayoutPresentation.seamInputs(
            showsBuddyLeaderboard: showsHomeBuddyLeaderboard
        )
        let statsContentHeight = seamInputs.statsPanelContentHeight

        BlueSheetTabRootPage(
            configuration: .tabRoot(accessibilityRootIdentifier: "GoDive.Home"),
            seamInputs: seamInputs,
            isNavigationStackAtRoot: isHomeNavigationStackAtRoot,
            allowsTopChromeHitTesting: !homeHeroInteractionOverlayActive,
            onLayoutResolved: { layout in
                HomeOverviewLayoutAnchor.publishHomeTabRootLayout(
                    layout,
                    statsPanelContentHeight: statsContentHeight,
                    showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard
                )
            },
            frozenRootViewportHeight: $frozenHomeRootViewportHeight
        ) { context in
            homeTabRootHeroBand(context: context)
        } heroOverlay: { _ in
            EmptyView()
        } panelContent: { _ in
            homeStatsPanelContent
        } topChrome: { safeTop, topInset, _ in
            BlueSheetHomeTopChrome(
                safeTop: safeTop,
                topInset: topInset,
                title: "Home"
            ) {
                homeProfileHeaderButton
            }
        }
        .animation(nil, value: carouselHighlights.isEmpty)
        .animation(nil, value: showsHomeBuddyLeaderboard)
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeDashboard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(HomeHeroInteractionOverlayKey.self) { homeHeroInteractionOverlayActive = $0 }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationInteractivePopGestureForHiddenNavBar()
            .navigationDestination(for: HomeRoute.self, destination: homeDestination)
            .restoresRootTabBarWhenStackIsEmpty(isHomeNavigationStackAtRoot)
            .animation(nil, value: path.count)
            .onAppear { handleHomeRootAppear() }
            .task(id: ownerProfileID) {
                await reloadHomeNavigationCatalogsIfNeeded()
            }
            .onChange(of: path.count) { oldCount, newCount in
                if newCount == 0, oldCount > 0 {
                    handleReturnToHomeRoot()
                }
            }
            .onChange(of: ownerDiveActivities.count) { _, _ in scheduleHomeOverviewRebuild() }
            .onChange(of: automaticallyRenumberDives) { _, _ in scheduleHomeOverviewRebuild() }
            .onChange(of: buddyRosterFingerprint) { _, _ in scheduleHomeOverviewRebuild() }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveBuddyRosterDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleHomeOverviewRebuild()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveActivityMediaDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                scheduleHomeOverviewRebuild()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    handleHomeForegroundActivation()
                default:
                    break
                }
            }
        }
        .environment(\.openCatalogDiveSiteDetail) { siteID in
            path.append(.diveSite(siteID))
            TripDetailMapNavigationDebug.parentStackAppendedRoute(
                stack: .home,
                siteID: siteID,
                pathCountAfterAppend: path.count
            )
        }
        .environment(\.openTripPlanner) {
            path.append(.tripPlanner)
        }
        .environment(\.openTripDetail) { tripID in
            path.append(.tripDetail(tripID))
        }
        .environment(\.openTripDetailMedia) { launch in
            path.append(.tripDetailMedia(tripID: launch.tripID, mediaID: launch.mediaID))
        }
    }

    private var profilePhotoForHeader: Data? {
        accountSession.currentProfile?.profilePhoto
    }

    private var homeProfileHeaderButton: some View {
        Button {
            path.append(.profile)
        } label: {
            ProfileAvatarView(
                profilePhoto: profilePhotoForHeader,
                diameter: Layout.profileAvatarDiameter
            )
            .frame(width: Layout.profileAvatarDiameter, height: Layout.profileAvatarDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Profile")
        .accessibilityIdentifier("Home.ProfileLink")
    }

    @ViewBuilder
    private func homeTabRootHeroBand(context: BlueSheetHeaderPageLayoutContext) -> some View {
        BlueSheetDetailHeroBandFill(
            accessibilityIdentifier: carouselHighlights.isEmpty
                ? "Home.MediaCarousel.Empty.Hero"
                : "Home.MediaCarousel.Hero"
        ) {
            if carouselHighlights.isEmpty {
                HomeMediaCarouselEmptyPlaceholder(
                    containerWidth: context.geometryWidth,
                    topSafeAreaInset: context.heroTopSafeAreaInset,
                    headerOverlayHeight: context.topInset,
                    heroBandHeight: context.heroHeight,
                    context: ownerDiveActivities.isEmpty ? .noLoggedActivities : .noMediaYet
                )
            } else {
                homeCarouselContent(context: context)
            }
        }
    }

    @ViewBuilder
    private func homeCarouselContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        HomeMediaCarouselSection(
            highlights: carouselHighlights,
            mediaByID: homeAggregate.mediaByID,
            sightings: homeAggregate.ownerSightings,
            marineLifeCatalog: marineLifeCatalog,
            taggedBuddyRowsByMediaID: homeAggregate.taggedBuddyRowsByMediaID,
            ownerProfileID: ownerProfileID,
            containerWidth: context.geometryWidth,
            topSafeAreaInset: context.heroTopSafeAreaInset,
            headerOverlayHeight: context.topInset,
            heroBandHeight: context.heroHeight,
            appliesTopSafeAreaBleed: false,
            selfBuddyID: selfBuddyID,
            isHeroPlaybackActive: isHomeNavigationStackAtRoot,
            onOpenDive: { path.append(.diveDetail($0)) },
            onOpenMedia: { diveID, mediaID in path.append(.diveMedia(diveID: diveID, mediaID: mediaID)) },
            onOpenBuddy: openBuddyOrProfile
        )
    }

    private func openBuddyOrProfile(buddyID: UUID) {
        if DiveBuddySelfRepresentation.isSelfBuddyID(buddyID, selfBuddyID: selfBuddyID) {
            path.append(.profile)
        } else {
            path.append(.diveBuddy(buddyID))
        }
    }

    @ViewBuilder
    private var homeStatsPanelContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HomeLifetimeStatsSection(
                stats: homeAggregate.lifetimeStats,
                buddyLeaderboard: homeAggregate.buddyLeaderboard,
                unitSystem: diveDisplayUnitSystem,
                onOpenLeaderboard: { path.append(.lifetimeStatsLeaderboard($0)) },
                onOpenBuddy: openBuddyOrProfile
            )
            .id(homeAggregate.contentFingerprint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func homeDestination(for route: HomeRoute) -> some View {
        switch route {
        case .profile:
            ProfileView(ownerProfileID: ownerProfileID)
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
        case .diveDetail(let id):
            if let activity = ownerDiveActivities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                missingDestinationLabel("This dive is no longer in your log.")
            }
        case .diveMedia(let diveID, let mediaID):
            if let activity = ownerDiveActivities.first(where: { $0.id == diveID }) {
                ViewSingleActivity(activity: activity, initialMediaFocusID: mediaID)
            } else {
                missingDestinationLabel("This dive is no longer in your log.")
            }
        case .diveSite(let siteID):
            ExploreDiveSiteDetailHost(
                siteID: siteID,
                ownerProfileID: ownerProfileID,
                onOpenDive: { path.append(.diveDetail($0)) }
            )
        case .marineLife(let uuid):
            if let species = marineLifeCatalog.first(where: { $0.uuid == uuid }) {
                FieldGuideMarineLifeDetailView(
                    species: species,
                    ownerProfileID: ownerProfileID
                ) { activityID in
                    path.append(.diveDetail(activityID))
                }
            } else {
                missingDestinationLabel("This species is no longer in the catalog.")
            }
        case .diveBuddy(let buddyID):
            if DiveBuddySelfRepresentation.isSelfBuddyID(buddyID, selfBuddyID: selfBuddyID) {
                ProfileView(ownerProfileID: ownerProfileID)
            } else if let buddy = ownerDiveBuddies.first(where: { $0.id == buddyID }) {
                ViewDiveBuddyDetails(buddy: buddy)
                    .hidesBottomTabBarWhenPushed()
            } else {
                missingDestinationLabel("This buddy is no longer on your roster.")
            }
        case .lifetimeStatsLeaderboard(let kind):
            HomeLifetimeStatsLeaderboardView(
                kind: kind,
                diveStatsInputs: homeAggregate.diveStatsInputs,
                activities: ownerDiveActivities,
                diveSites: diveSiteCatalog,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: diveDisplayUnitSystem,
                automaticallyRenumberDives: automaticallyRenumberDives,
                sightings: homeAggregate.sightingCountInputs,
                onOpenDive: { path.append(.diveDetail($0)) },
                onOpenSite: { path.append(.diveSite($0)) },
                onOpenSpecies: { path.append(.marineLife($0)) }
            )
        }
    }


    private func missingDestinationLabel(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private func handleHomeRootAppear() {
        switch HomeRootAppearPresentation.handleRootAppearAction(
            hasPerformedInitialHomeBuild: hasPerformedInitialHomeBuild
        ) {
        case .scheduleImmediateInitialRebuild:
            hasPerformedInitialHomeBuild = true
            if isCelebrationShellPrewarmActive {
                SignInCelebrationTransitionDiagnostics.mark("Home_handleHomeRootAppear_initial_rebuild_during_prewarm")
            } else {
                SignInCelebrationTransitionDiagnostics.mark("Home_handleHomeRootAppear_initial_rebuild")
            }
            scheduleHomeOverviewRebuild(immediate: true, source: .initialRootAppear)
        case .handleReturnToRoot:
            handleReturnToHomeRoot()
        }
    }

    private func handleReturnToHomeRoot() {
        if HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
            hasPerformedInitialBuild: hasPerformedInitialHomeBuild,
            carouselSlidesAreDisplayable: carouselSlidesAreDisplayable(using: homeAggregate),
            hasCarouselHighlights: !carouselHighlights.isEmpty
        ) {
            scheduleCarouselWarmupIfNeeded(using: homeAggregate)
            return
        }
        scheduleHomeOverviewRebuild(immediate: true)
    }

    private func handleHomeForegroundActivation() {
        guard hasPerformedInitialHomeBuild else {
            scheduleHomeOverviewRebuild(immediate: true)
            return
        }
        if HomeReturnNavigationPresentation.shouldSkipFullRebuildOnForegroundActivation(
            hasPerformedInitialBuild: hasPerformedInitialHomeBuild,
            carouselSlidesAreDisplayable: carouselSlidesAreDisplayable(using: homeAggregate),
            hasCarouselHighlights: !carouselHighlights.isEmpty
        ) {
            scheduleCarouselWarmupIfNeeded(using: homeAggregate)
            return
        }
        scheduleHomeOverviewRebuild()
    }

    private func scheduleHomeOverviewRebuild(
        debounceNanoseconds: UInt64 = 80_000_000,
        immediate: Bool = false,
        source: HomeOverviewRebuildPresentation.Source = .incidental
    ) {
        if HomeOverviewRebuildPresentation.shouldSkipSchedule(
            isCelebrationShellPrewarmActive: isCelebrationShellPrewarmActive,
            hasPerformedInitialHomeBuild: hasPerformedInitialHomeBuild,
            source: source
        ) {
            return
        }
        homeOverviewRebuildGeneration += 1
        let generation = homeOverviewRebuildGeneration

        Task {
            if immediate {
                await HomeOverviewRebuildScheduler.shared.runImmediately {
                    await performHomeOverviewRebuild(generation: generation)
                }
            } else {
                await HomeOverviewRebuildScheduler.shared.schedule(
                    debounceNanoseconds: debounceNanoseconds
                ) {
                    await performHomeOverviewRebuild(generation: generation)
                }
            }
        }
    }

    @MainActor
    private func performHomeOverviewRebuild(generation: Int) async {
        guard generation == homeOverviewRebuildGeneration else { return }
        let signpostID = SignInCelebrationTransitionDiagnostics.begin(.homeOverviewRebuild)
        await rebuildHomeOverviewAsync()
        SignInCelebrationTransitionDiagnostics.end(.homeOverviewRebuild, signpostID: signpostID)
    }

    @MainActor
    private func rebuildHomeOverviewAsync() async {
        if marineLifeCatalog.isEmpty {
            await reloadHomeNavigationCatalogsIfNeeded()
        }
        let ownerProfile = accountSession.currentProfile
        selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: ownerProfile,
            modelContext: modelContext
        )
        let built = await HomeOverviewAggregateBuilder.buildAsync(
            activities: ownerDiveActivities,
            marineLifeCatalog: marineLifeCatalog,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: diveDisplayUnitSystem,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext
        )
        homeAggregate = built
        if let ownerProfileID {
            OwnerDiveIndexSessionCache.publish(
                activities: ownerDiveActivities,
                ownerProfileID: ownerProfileID
            )
        }
        refreshCarouselHighlightsIfNeeded(using: built)
    }

    private func reloadHomeNavigationCatalogsIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedNavigationCatalogs || marineLifeCatalog.isEmpty else { return }
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
        hasLoadedNavigationCatalogs = true
    }

    private func refreshCarouselHighlightsIfNeeded(using aggregate: HomeOverviewAggregate) {
        guard let ownerProfileID else {
            carouselHighlights = []
            lastCarouselFingerprint = 0
            lastCarouselTagFingerprint = 0
            hasCarouselSessionWarmCompleted = false
            return
        }

        let fingerprintChanged = aggregate.carouselFingerprint != lastCarouselFingerprint
        let tagFingerprintChanged = aggregate.carouselTagFingerprint != lastCarouselTagFingerprint

        if fingerprintChanged || carouselHighlights.isEmpty {
            lastCarouselFingerprint = aggregate.carouselFingerprint
            lastCarouselTagFingerprint = aggregate.carouselTagFingerprint
            hasCarouselSessionWarmCompleted = false
            carouselHighlights = buildCarouselHighlights(from: aggregate, ownerProfileID: ownerProfileID)
        } else if tagFingerprintChanged {
            lastCarouselTagFingerprint = aggregate.carouselTagFingerprint
            carouselHighlights = refreshCarouselHighlightTagCounts(
                carouselHighlights,
                using: aggregate
            )
        }

        guard !carouselHighlights.isEmpty else {
            hasCarouselSessionWarmCompleted = false
            return
        }

        scheduleCarouselWarmupIfNeeded(using: aggregate)
    }

    private func carouselSlidesAreDisplayable(using aggregate: HomeOverviewAggregate) -> Bool {
        guard !carouselHighlights.isEmpty else { return false }
        return HomeMediaHighlightWarmup.carouselHighlightsAreDisplayable(
            carouselHighlights,
            mediaByID: aggregate.mediaByID
        )
    }

    private func scheduleCarouselWarmupIfNeeded(using aggregate: HomeOverviewAggregate) {
        guard !carouselHighlights.isEmpty else {
            hasCarouselSessionWarmCompleted = false
            return
        }

        #if canImport(UIKit)
        seedCarouselSessionCache(using: aggregate)
        #endif

        if let ownerProfileID {
            HomeCarouselLaunchPreload.storeTodaysPicks(
                ownerProfileID: ownerProfileID,
                highlights: carouselHighlights,
                mediaByID: aggregate.mediaByID
            )
        }

        let allDisplayable = carouselSlidesAreDisplayable(using: aggregate)
        if !allDisplayable {
            hasCarouselSessionWarmCompleted = false
        }

        HomeMediaCarouselDebug.warmupScheduled(
            alreadyWarmed: hasCarouselSessionWarmCompleted,
            displayableBeforeWarm: allDisplayable
        )

        guard !hasCarouselSessionWarmCompleted else { return }

        let limitedHighlights = Array(
            carouselHighlights.prefix(HomeMediaHighlightPresentation.carouselLimit)
        )

        Task { @MainActor in
            #if canImport(UIKit)
            let mediaRows = limitedHighlights.compactMap { aggregate.mediaByID[$0.mediaID] }
            // Existing previewJPEGData is already seeded via seedCarouselSessionCache.
            // Warm heroes + preview videos first; fill missing JPEGs after so PhotoKit isn't flooded.
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: aggregate.mediaByID
            )
            await DiveMediaPreviewStorage.ensureStoredPreviews(
                for: mediaRows,
                modelContext: modelContext
            )
            #else
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: aggregate.mediaByID
            )
            #endif
            hasCarouselSessionWarmCompleted = true
            let displayable = Dictionary(
                uniqueKeysWithValues: limitedHighlights.map { highlight in
                    let media = aggregate.mediaByID[highlight.mediaID]
                    let ready = media.map {
                        HomeMediaHighlightWarmup.isHighlightDisplayable(highlight, media: $0)
                    } ?? false
                    return (highlight.mediaID, ready)
                }
            )
            HomeMediaCarouselDebug.warmupFinished(
                mediaIDs: limitedHighlights.map(\.mediaID),
                displayableByMediaID: displayable
            )
        }
    }

    #if canImport(UIKit)
    private func seedCarouselSessionCache(using aggregate: HomeOverviewAggregate) {
        let limited = Array(carouselHighlights.prefix(HomeMediaHighlightPresentation.carouselLimit))
        let mediaRows = limited.compactMap { aggregate.mediaByID[$0.mediaID] }
        DiveMediaPreviewStorage.seedSessionCache(for: mediaRows)
        HomeMediaHighlightWarmup.repinCarouselSessionCache(
            highlights: carouselHighlights,
            mediaByID: aggregate.mediaByID
        )
    }
    #endif

    private func buildCarouselHighlights(
        from aggregate: HomeOverviewAggregate,
        ownerProfileID: UUID
    ) -> [HomeMediaHighlight] {
        let taggedSpeciesCountByMediaID = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: aggregate.mediaHighlightSightings,
            ownerDiveIDs: aggregate.ownerDiveIDs
        )
        let taggedBuddyCountByMediaID = HomeMediaHighlightPresentation.taggedBuddyCountByMediaID(
            buddyTags: aggregate.mediaHighlightBuddyTags,
            ownerDiveIDs: aggregate.ownerDiveIDs
        )
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: HomeMediaHighlightWarmup.highlightSources(from: aggregate.ownerMediaPhotos),
            dives: aggregate.diveStatsInputs,
            taggedSpeciesCountByMediaID: taggedSpeciesCountByMediaID,
            taggedBuddyCountByMediaID: taggedBuddyCountByMediaID
        )
        return HomeMediaHighlightPresentation.highlightsForOwner(
            ownerProfileID: ownerProfileID,
            candidates: candidates
        )
    }

    private func refreshCarouselHighlightTagCounts(
        _ highlights: [HomeMediaHighlight],
        using aggregate: HomeOverviewAggregate
    ) -> [HomeMediaHighlight] {
        let taggedSpeciesCountByMediaID = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: aggregate.mediaHighlightSightings,
            ownerDiveIDs: aggregate.ownerDiveIDs
        )
        let taggedBuddyCountByMediaID = HomeMediaHighlightPresentation.taggedBuddyCountByMediaID(
            buddyTags: aggregate.mediaHighlightBuddyTags,
            ownerDiveIDs: aggregate.ownerDiveIDs
        )
        return HomeMediaHighlightPresentation.highlightsByRefreshingTagCounts(
            highlights,
            taggedSpeciesCountByMediaID: taggedSpeciesCountByMediaID,
            taggedBuddyCountByMediaID: taggedBuddyCountByMediaID
        )
    }
}

#Preview {
    LogOverviewView(ownerProfileID: nil)
}
