import Combine
import SwiftData
import SwiftUI

struct LogOverviewView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query(sort: \DiveMediaPhoto.sortOrder) private var allMediaPhotos: [DiveMediaPhoto]
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query private var allSightings: [SightingInstance]
    @Query private var ownerDiveBuddies: [DiveBuddy]

    private let ownerProfileID: UUID?

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var path: [HomeRoute] = []
    @State private var carouselHighlights: [HomeMediaHighlight] = []
    @State private var homeAggregate = HomeOverviewAggregate.empty
    @State private var lastCarouselFingerprint = 0
    @State private var lastCarouselTagFingerprint = 0
    @State private var hasCarouselSessionWarmCompleted = false
    @State private var hasPerformedInitialHomeBuild = false
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
        static let profileAvatarDiameter: CGFloat = 48
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

    private func homeOverviewLayoutMetrics(
        for proxy: GeometryProxy,
        viewportHeight: CGFloat
    ) -> HomeOverviewLayout.Metrics {
        let statsContentHeight = HomeLifetimeStatsLayout.estimatedPanelContentHeight(
            showsBuddyLeaderboard: showsHomeBuddyLeaderboard
        )
        return HomeOverviewLayout.metrics(
            viewportHeight: viewportHeight,
            screenWidth: proxy.size.width,
            topSafeAreaInset: proxy.safeAreaInsets.top,
            statsPanelContentHeight: statsContentHeight
        )
    }

    private func resolvedHomeViewportHeight(geometryHeight: CGFloat) -> CGFloat {
        HomeRootViewportPresentation.resolvedViewportHeight(
            geometryHeight: geometryHeight,
            isNavigationStackAtRoot: isHomeNavigationStackAtRoot,
            frozenRootViewportHeight: frozenHomeRootViewportHeight
        ).height
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        if ownerDiveActivities.isEmpty {
                            Color.clear
                                .frame(height: headerClearance)

                            Spacer(minLength: AppTheme.Spacing.lg)

                            homeEmptyState
                                .padding(.horizontal, AppTheme.Spacing.lg)

                            Spacer(minLength: AppTheme.Spacing.lg)
                        } else {
                            homeDashboard(for: proxy, hasCarouselMedia: !carouselHighlights.isEmpty)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                    AppHeader(title: "Home", showsBackButton: false, statusBarSafeAreaTop: proxy.safeAreaInsets.top) {
                        Button {
                            path.append(.profile)
                        } label: {
                            ProfileAvatarView(
                                profilePhoto: profilePhotoForHeader,
                                diameter: Layout.profileAvatarDiameter
                            )
                            .frame(minWidth: Layout.profileAvatarDiameter, minHeight: Layout.profileAvatarDiameter)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Profile")
                        .accessibilityIdentifier("Home.ProfileLink")
                    }
                    .allowsHitTesting(!homeHeroInteractionOverlayActive)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.Colors.screenBackgroundGradient
                    .ignoresSafeArea()
            }
            .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                if height > 0 { headerClearance = height }
            }
            .onPreferenceChange(HomeHeroInteractionOverlayKey.self) { homeHeroInteractionOverlayActive = $0 }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationInteractivePopGestureForHiddenNavBar()
            .navigationDestination(for: HomeRoute.self, destination: homeDestination)
            .restoresRootTabBarWhenStackIsEmpty(isHomeNavigationStackAtRoot)
            .animation(nil, value: path.count)
            .onAppear { handleHomeRootAppear() }
            .onChange(of: path.count) { oldCount, newCount in
                if newCount == 0, oldCount > 0 {
                    handleReturnToHomeRoot()
                }
            }
            .onChange(of: ownerDiveActivities.count) { _, _ in rebuildHomeOverview() }
            .onChange(of: allMediaPhotos.count) { _, _ in rebuildHomeOverview() }
            .onChange(of: allSightings.count) { _, _ in rebuildHomeOverview() }
            .onChange(of: automaticallyRenumberDives) { _, _ in rebuildHomeOverview() }
            .onChange(of: buddyRosterFingerprint) { _, _ in rebuildHomeOverview() }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveBuddyRosterDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                rebuildHomeOverview()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .diveActivityMediaDidChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                rebuildHomeOverview()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    rebuildHomeOverview()
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

    @ViewBuilder
    private func homeDashboard(for proxy: GeometryProxy, hasCarouselMedia: Bool) -> some View {
        let statsContentHeight = HomeLifetimeStatsLayout.estimatedPanelContentHeight(
            showsBuddyLeaderboard: showsHomeBuddyLeaderboard
        )
        let viewportHeight = resolvedHomeViewportHeight(geometryHeight: proxy.size.height)
        let homeLayout = homeOverviewLayoutMetrics(for: proxy, viewportHeight: viewportHeight)
        let bottomInset = proxy.safeAreaInsets.bottom

        VStack(spacing: -HomeLifetimeStatsLayout.panelOverlap) {
            if hasCarouselMedia {
                homeCarouselBlock(
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: proxy.safeAreaInsets.top
                )
                .frame(height: homeLayout.heroHeight)
            } else {
                HomeMediaCarouselEmptyPlaceholder(
                    containerWidth: proxy.size.width,
                    topSafeAreaInset: proxy.safeAreaInsets.top
                )
                .padding(.top, -proxy.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
                .frame(height: homeLayout.heroHeight)
            }

            homeStatsPanel(overlapsMedia: true, bottomSafeAreaInset: bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: proxy.size.width, height: viewportHeight, alignment: .top)
        .onChange(of: proxy.size.height, initial: true) { _, height in
            guard isHomeNavigationStackAtRoot, height > 0 else { return }
            frozenHomeRootViewportHeight = height
        }
        .onAppear {
            HomeOverviewLayoutAnchor.publish(
                HomeOverviewLayoutAnchor.RootSnapshot(
                    heroHeight: homeLayout.heroHeight,
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: proxy.safeAreaInsets.top,
                    statsPanelContentHeight: statsContentHeight,
                    showsBuddyLeaderboard: showsHomeBuddyLeaderboard,
                    homeTabViewportHeight: viewportHeight
                )
            )
        }
    }

    @ViewBuilder
    private func homeCarouselBlock(screenWidth: CGFloat, topSafeAreaInset: CGFloat) -> some View {
        HomeMediaCarouselSection(
            highlights: carouselHighlights,
            mediaByID: homeAggregate.mediaByID,
            sightings: allSightings,
            marineLifeCatalog: marineLifeCatalog,
            taggedBuddyRowsByMediaID: homeAggregate.taggedBuddyRowsByMediaID,
            ownerProfileID: ownerProfileID,
            containerWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            headerOverlayHeight: headerClearance,
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
    private func homeStatsPanel(overlapsMedia: Bool, bottomSafeAreaInset: CGFloat) -> some View {
        HomeLifetimeStatsPanel(
            overlapsMedia: overlapsMedia,
            bottomSafeAreaInset: bottomSafeAreaInset
        ) {
            homeStatsPanelContent
        }
        .zIndex(1)
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

    private var homeEmptyState: some View {
        AppComingSoonPlaceholder(
            systemImage: "water.waves",
            title: "Your diving home",
            message: "Import or log dives in the Logbook to unlock lifetime stats and a highlight reel from your media."
        )
        .padding(.top, AppTheme.Spacing.lg)
    }

    @ViewBuilder
    private func homeDestination(for route: HomeRoute) -> some View {
        switch route {
        case .profile:
            ProfileView()
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
            if let site = diveSites.first(where: { $0.id == siteID }) {
                ExploreDiveSiteDetailView(
                    site: site,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: { path.append(.diveDetail($0)) }
                )
            } else {
                missingDestinationLabel("This dive site is no longer in the catalog.")
            }
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
                ProfileView()
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
                diveSites: diveSites,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: diveDisplayUnitSystem,
                automaticallyRenumberDives: automaticallyRenumberDives,
                sightings: homeSightingCountInputs,
                onOpenDive: { path.append(.diveDetail($0)) },
                onOpenSite: { path.append(.diveSite($0)) },
                onOpenSpecies: { path.append(.marineLife($0)) }
            )
        }
    }

    private var homeSightingCountInputs: [HomeLifetimeStatsPresentation.SightingCountInput] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: marineLifeCatalog.map { ($0.uuid, $0) })
        let ownerDiveIDs = homeAggregate.ownerDiveIDs
        return allSightings.compactMap { sighting in
            guard let diveID = sighting.diveActivityID, ownerDiveIDs.contains(diveID) else { return nil }
            let name = sighting.marineLife?.commonName
                ?? catalogByUUID[sighting.marineLifeUUID]?.commonName
                ?? sighting.marineLifeUUID
            return HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: sighting.marineLifeUUID,
                commonName: name
            )
        }
    }

    private func missingDestinationLabel(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private func handleHomeRootAppear() {
        if !hasPerformedInitialHomeBuild {
            hasPerformedInitialHomeBuild = true
            rebuildHomeOverview()
            return
        }
        handleReturnToHomeRoot()
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
        rebuildHomeOverview()
    }

    private func rebuildHomeOverview() {
        let ownerProfile = accountSession.currentProfile
        selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: ownerProfile,
            modelContext: modelContext
        )
        let built = HomeOverviewAggregateBuilder.build(
            activities: ownerDiveActivities,
            allMediaPhotos: allMediaPhotos,
            allSightings: allSightings,
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

        Task {
            #if canImport(UIKit)
            let mediaRows = limitedHighlights.compactMap { aggregate.mediaByID[$0.mediaID] }
            await DiveMediaPreviewStorage.ensureStoredPreviews(
                for: mediaRows,
                modelContext: modelContext
            )
            #endif
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: aggregate.mediaByID
            )
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
