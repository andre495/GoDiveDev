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

    private let ownerProfileID: UUID?

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var path: [HomeRoute] = []
    @State private var carouselHighlights: [HomeMediaHighlight] = []
    @State private var isCarouselMediaReady = false

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
    }

    private var diveStatsInputs: [HomeDiveStatsInput] {
        let useChronologicalNumbers = AppUserSettings.automaticallyRenumberDives
        let chronologicalNumbers = useChronologicalNumbers
            ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: ownerDiveActivities)
            : [:]

        return ownerDiveActivities.map { activity in
            HomeDiveStatsInput(
                id: activity.id,
                maxDepthMeters: activity.maxDepthMeters,
                durationMinutes: activity.durationMinutes,
                diveSiteID: activity.diveSiteID,
                diveNumberLabel: HomeMediaHighlightPresentation.diveNumberLabel(
                    diveNumber: activity.diveNumber,
                    diveNumberExplicitlyNone: activity.diveNumberExplicitlyNone,
                    chronologicalIndex: chronologicalNumbers[activity.id],
                    useChronologicalNumbers: useChronologicalNumbers
                ),
                siteDisplayName: LogbookActivityRow.displayName(for: activity)
            )
        }
    }

    /// Recomputed whenever SwiftData publishes dive / sighting / media changes (**`@Query`**).
    private var lifetimeStats: HomeLifetimeStats {
        HomeLifetimeStatsPresentation.build(
            dives: diveStatsInputs,
            sightings: ownerSightingInputs
        )
    }

    private var ownerSightingInputs: [HomeLifetimeStatsPresentation.SightingCountInput] {
        let ownerDiveIDs = Set(ownerDiveActivities.map(\.id))
        let catalogByUUID = Dictionary(uniqueKeysWithValues: marineLifeCatalog.map { ($0.uuid, $0) })

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

    private var ownerMediaPhotos: [DiveMediaPhoto] {
        let ownerDiveIDs = Set(ownerDiveActivities.map(\.id))
        return allMediaPhotos.filter { photo in
            guard let diveID = photo.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
    }

    private var mediaByID: [UUID: DiveMediaPhoto] {
        Dictionary(uniqueKeysWithValues: ownerMediaPhotos.map { ($0.id, $0) })
    }

    /// Changes when dives are added/removed/edited or related sighting/media rows change.
    private var homeOverviewRefreshToken: String {
        HomeOverviewRefreshToken.make(
            dives: diveStatsInputs,
            sightingCount: ownerSightingInputs.count,
            mediaCount: ownerMediaPhotos.count
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
                            if !carouselHighlights.isEmpty {
                                VStack(spacing: -HomeLifetimeStatsLayout.panelOverlap) {
                                    homeCarouselBlock(
                                        screenWidth: proxy.size.width,
                                        topSafeAreaInset: proxy.safeAreaInsets.top
                                    )

                                    homeStatsPanel(overlapsMedia: true)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.bottom, proxy.safeAreaInsets.bottom)
                            } else {
                                VStack(spacing: -HomeLifetimeStatsLayout.panelOverlap) {
                                    HomeMediaCarouselEmptyPlaceholder(
                                        containerWidth: proxy.size.width,
                                        topSafeAreaInset: proxy.safeAreaInsets.top
                                    )
                                    .padding(.top, -proxy.safeAreaInsets.top)
                                    .ignoresSafeArea(edges: .top)

                                    homeStatsPanel(overlapsMedia: true)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.bottom, proxy.safeAreaInsets.bottom)
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                    AppHeader(title: "Home", showsBackButton: false, statusBarSafeAreaTop: proxy.safeAreaInsets.top) {
                        NavigationLink {
                            ProfileView()
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
            .onAppear { refreshCarouselHighlights() }
            .onChange(of: homeOverviewRefreshToken) { _, _ in
                refreshCarouselHighlights()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshCarouselHighlights()
                }
            }
        }
    }

    private var profilePhotoForHeader: Data? {
        accountSession.currentProfile?.profilePhoto
    }

    @ViewBuilder
    private func homeCarouselBlock(screenWidth: CGFloat, topSafeAreaInset: CGFloat) -> some View {
        if isCarouselMediaReady {
            HomeMediaCarouselSection(
                highlights: carouselHighlights,
                mediaByID: mediaByID,
                divesByID: Dictionary(uniqueKeysWithValues: ownerDiveActivities.map { ($0.id, $0) }),
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
    private func homeStatsPanel(overlapsMedia: Bool) -> some View {
        HomeLifetimeStatsPanel(overlapsMedia: overlapsMedia) {
            homeStatsPanelContent
        }
        .zIndex(1)
    }

    @ViewBuilder
    private var homeStatsPanelContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HomeLifetimeStatsSection(
                stats: lifetimeStats,
                unitSystem: diveDisplayUnitSystem,
                onOpenDive: { path.append(.diveDetail($0)) },
                onOpenSite: { path.append(.diveSite($0)) },
                onOpenSpecies: { path.append(.marineLife($0)) }
            )
            .id(homeOverviewRefreshToken)
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
        }
    }

    private func missingDestinationLabel(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding()
    }

    private func refreshCarouselHighlights() {
        guard let ownerProfileID else {
            carouselHighlights = []
            isCarouselMediaReady = false
            return
        }

        let taggedSpeciesCountByMediaID = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: ownerMediaHighlightSightings,
            ownerDiveIDs: Set(ownerDiveActivities.map(\.id))
        )
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: HomeMediaHighlightWarmup.highlightSources(from: ownerMediaPhotos),
            dives: diveStatsInputs,
            taggedSpeciesCountByMediaID: taggedSpeciesCountByMediaID
        )

        carouselHighlights = HomeMediaHighlightPresentation.highlightsForOwner(
            ownerProfileID: ownerProfileID,
            candidates: candidates
        )
        isCarouselMediaReady = isFirstCarouselHighlightReady()

        Task {
            await HomeMediaHighlightWarmup.warmHighlights(
                carouselHighlights,
                mediaByID: mediaByID
            )
            isCarouselMediaReady = true
        }
    }

    private func isFirstCarouselHighlightReady() -> Bool {
        guard let first = carouselHighlights.first,
              let media = mediaByID[first.mediaID] else {
            return carouselHighlights.isEmpty
        }
        return HomeMediaHighlightWarmup.isHighlightDisplayable(first, media: media)
    }

    private var ownerMediaHighlightSightings: [HomeMediaHighlightSightingInput] {
        let ownerDiveIDs = Set(ownerDiveActivities.map(\.id))
        return allSightings.map {
            HomeMediaHighlightSightingInput(
                mediaPhotoID: $0.mediaPhotoID,
                diveActivityID: $0.diveActivityID
            )
        }
        .filter { sighting in
            guard let diveID = sighting.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
    }
}

#Preview {
    LogOverviewView(ownerProfileID: nil)
}
