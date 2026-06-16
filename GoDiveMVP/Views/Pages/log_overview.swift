import SwiftData
import SwiftUI

struct LogOverviewView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var isCarouselMediaReady = false
    @State private var homeAggregate = HomeOverviewAggregate.empty
    @State private var lastCarouselFingerprint = 0
    @State private var hasCarouselSessionWarmCompleted = false
    @State private var hasPerformedInitialHomeBuild = false
    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

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

    private func homeOverviewLayoutMetrics(for proxy: GeometryProxy) -> HomeOverviewLayout.Metrics {
        let statsContentHeight = HomeLifetimeStatsLayout.estimatedPanelContentHeight(
            showsBuddyLeaderboard: showsHomeBuddyLeaderboard
        )
        return HomeOverviewLayout.metrics(
            viewportHeight: proxy.size.height,
            screenWidth: proxy.size.width,
            topSafeAreaInset: proxy.safeAreaInsets.top,
            statsPanelContentHeight: statsContentHeight
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    if !GoDiveUITestConfiguration.isActive {
                        WaterBubbleBackground()
                    }

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
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profile")
                        .accessibilityIdentifier("Home.ProfileLink")
                    }
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    rebuildHomeOverview()
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
        let homeLayout = homeOverviewLayoutMetrics(for: proxy)
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
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
    }

    @ViewBuilder
    private func homeCarouselBlock(screenWidth: CGFloat, topSafeAreaInset: CGFloat) -> some View {
        if isCarouselMediaReady {
            HomeMediaCarouselSection(
                highlights: carouselHighlights,
                mediaByID: homeAggregate.mediaByID,
                sightings: allSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                containerWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                headerOverlayHeight: headerClearance,
                onOpenDive: { path.append(.diveDetail($0)) },
                onOpenMedia: { diveID, mediaID in path.append(.diveMedia(diveID: diveID, mediaID: mediaID)) }
            )
        } else {
            HomeMediaCarouselLoadingPlaceholder(
                containerWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset
            )
            .padding(.top, -topSafeAreaInset)
            .ignoresSafeArea(edges: .top)
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
                onOpenDive: { path.append(.diveDetail($0)) },
                onOpenSite: { path.append(.diveSite($0)) },
                onOpenSpecies: { path.append(.marineLife($0)) },
                onOpenBuddy: { path.append(.diveBuddy($0)) }
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
                    ownerProfileID: ownerProfileID
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
            if let buddy = ownerDiveBuddies.first(where: { $0.id == buddyID }) {
                ViewDiveBuddyDetails(buddy: buddy)
            } else {
                missingDestinationLabel("This buddy is no longer on your roster.")
            }
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
            isCarouselMediaReady: isCarouselMediaReady,
            hasCarouselHighlights: !carouselHighlights.isEmpty
        ) {
            ensureCarouselReadyAfterReturn()
            return
        }
        rebuildHomeOverview()
    }

    private func ensureCarouselReadyAfterReturn() {
        guard !carouselHighlights.isEmpty else {
            isCarouselMediaReady = false
            return
        }
        let allDisplayable = HomeMediaHighlightWarmup.carouselHighlightsAreDisplayable(
            carouselHighlights,
            mediaByID: homeAggregate.mediaByID
        )
        isCarouselMediaReady = hasCarouselSessionWarmCompleted
            || allDisplayable
            || isFirstCarouselHighlightReady(aggregate: homeAggregate)
        guard !allDisplayable || !hasCarouselSessionWarmCompleted else { return }
        Task {
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: homeAggregate.mediaByID
            )
            hasCarouselSessionWarmCompleted = true
            isCarouselMediaReady = true
        }
    }

    private func rebuildHomeOverview() {
        let built = HomeOverviewAggregateBuilder.build(
            activities: ownerDiveActivities,
            allMediaPhotos: allMediaPhotos,
            allSightings: allSightings,
            marineLifeCatalog: marineLifeCatalog,
            automaticallyRenumberDives: automaticallyRenumberDives,
            ownerProfileID: ownerProfileID
        )
        homeAggregate = built
        refreshCarouselHighlightsIfNeeded(using: built)
    }

    private func refreshCarouselHighlightsIfNeeded(using aggregate: HomeOverviewAggregate) {
        guard let ownerProfileID else {
            carouselHighlights = []
            isCarouselMediaReady = false
            lastCarouselFingerprint = 0
            hasCarouselSessionWarmCompleted = false
            return
        }

        let fingerprintChanged = aggregate.carouselFingerprint != lastCarouselFingerprint
        if fingerprintChanged || carouselHighlights.isEmpty {
            lastCarouselFingerprint = aggregate.carouselFingerprint
            hasCarouselSessionWarmCompleted = false
            carouselHighlights = buildCarouselHighlights(from: aggregate, ownerProfileID: ownerProfileID)
        }

        guard !carouselHighlights.isEmpty else {
            isCarouselMediaReady = false
            hasCarouselSessionWarmCompleted = false
            return
        }

        let allDisplayable = HomeMediaHighlightWarmup.carouselHighlightsAreDisplayable(
            carouselHighlights,
            mediaByID: aggregate.mediaByID
        )
        isCarouselMediaReady = hasCarouselSessionWarmCompleted
            || allDisplayable
            || isFirstCarouselHighlightReady(aggregate: aggregate)

        guard !allDisplayable || !hasCarouselSessionWarmCompleted else { return }

        Task {
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: aggregate.mediaByID
            )
            hasCarouselSessionWarmCompleted = true
            isCarouselMediaReady = true
        }
    }

    private func buildCarouselHighlights(
        from aggregate: HomeOverviewAggregate,
        ownerProfileID: UUID
    ) -> [HomeMediaHighlight] {
        let taggedSpeciesCountByMediaID = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: aggregate.mediaHighlightSightings,
            ownerDiveIDs: aggregate.ownerDiveIDs
        )
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: HomeMediaHighlightWarmup.highlightSources(from: aggregate.ownerMediaPhotos),
            dives: aggregate.diveStatsInputs,
            taggedSpeciesCountByMediaID: taggedSpeciesCountByMediaID
        )
        return HomeMediaHighlightPresentation.highlightsForOwner(
            ownerProfileID: ownerProfileID,
            candidates: candidates
        )
    }

    private func isFirstCarouselHighlightReady(aggregate: HomeOverviewAggregate) -> Bool {
        guard let first = carouselHighlights.first,
              let media = aggregate.mediaByID[first.mediaID] else {
            return carouselHighlights.isEmpty
        }
        return HomeMediaHighlightWarmup.isHighlightDisplayable(first, media: media)
    }
}

#Preview {
    LogOverviewView(ownerProfileID: nil)
}
