import SwiftData
import SwiftUI

/// GoDive friend profile — stats / shared activities / shared media; local buddies use **`ViewDiveBuddyDetails`**.
struct FriendProfileView: View {
    let friend: GoDiveFriendGraphService.FriendEdge

    @Environment(\.modelContext) private var modelContext
    @Environment(AccountSession.self) private var accountSession

    @State private var profile: GoDiveFriendGraphService.PublicProfileSummary?
    @State private var sharedDiveCount: Int?
    @State private var sharedDives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = []
    @State private var togetherActivityIDs: Set<UUID> = []
    @State private var togetherDiveActivities: [DiveActivity] = []
    @State private var activityFilter: FriendProfileActivityListFilter = .all
    @State private var sharedMediaItems: [FriendSharedMediaPresentation.DisplayItem] = []
    @State private var sharedMediaDiveByMediaID:
        [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive] = [:]
    @State private var fullscreenSelectedMediaID: String?
    @State private var lifetimeStats: HomeLifetimeStats = HomeLifetimeStatsPresentation.build(
        dives: [],
        sightings: []
    )
    @State private var isLoadingSharedContent = true
    @State private var selectedSharedDive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive?
    @State private var allowsHeroVideoAutoplay = false
    @State private var friendHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var friendMapPins: [TripDetailMapPin] = []
    @State private var showsDeferredFriendMap = false

    private enum Layout {
        static let avatarDiameter = DiveBuddyDetailPresentation.profileAvatarDiameter
        static let avatarOverlapOffset = DiveBuddyDetailPresentation.avatarOverlapOffset()
    }

    private var displayName: String {
        profile?.displayName ?? friend.displayName
    }

    private var photoURL: String? {
        profile?.photoURL ?? friend.photoURL
    }

    private var diveDisplayUnitSystem: DiveDisplayUnitSystem {
        AppUserSettings.diveDisplayUnitSystem()
    }

    private var currentFirebaseUID: String? {
        GoDiveFirebaseAuthSession.currentFirebaseUID()
    }

    private var filteredSharedDives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] {
        FriendProfileSharedDiveListPresentation.filteredDives(
            sharedDives,
            filter: activityFilter,
            togetherActivityIDs: togetherActivityIDs,
            currentFirebaseUID: currentFirebaseUID
        )
    }

    private var sharedActivityRows: [DiveLogbookRowDisplayData] {
        FriendProfileSharedDiveListPresentation.logbookRows(
            from: filteredSharedDives,
            unitSystem: diveDisplayUnitSystem
        )
    }

    private var resolvedHero: FriendProfileHeroPresentation.ResolvedHero? {
        FriendProfileHeroPresentation.resolvedHero(
            profileHeroURL: profile?.profileHeroURL ?? friend.profileHeroURL,
            profileHeroMediaKind: profile?.profileHeroMediaKind ?? friend.profileHeroMediaKind,
            sharedDives: sharedDives
        )
    }

    private var friendHasAssociatedMedia: Bool {
        resolvedHero != nil
    }

    private var friendHasMapContent: Bool {
        !friendMapPins.isEmpty
    }

    private var showsFriendHeroModeToggle: Bool {
        PushedDetailHeroModePresentation.showsModeToggle(
            hasAssociatedMedia: friendHasAssociatedMedia,
            hasMapContent: friendHasMapContent
        )
    }

    private var diveCountLabel: String {
        if let sharedDiveCount {
            return ProfilePresentation.diveActivityCountLabel(sharedDiveCount)
        }
        return ProfilePresentation.diveActivityCountLabel(0)
    }

    var body: some View {
        BlueSheetDetailPage(
            configuration: DiveBuddyDetailPresentation.identityBlueSheetPageConfiguration(
                accessibilityRootIdentifier: "FriendProfile.Root",
                usesProfileBubblePanelBackground: true
            ),
            hero: { context in
                friendHeroBandContent(context: context)
            },
            heroOverlay: { _ in
                if showsFriendHeroModeToggle {
                    PushedDetailHeroModeToggle(
                        selectedMode: $friendHeroMode,
                        accessibilityIdentifierPrefix: "FriendProfile.Hero.ModeToggle"
                    )
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                    .zIndex(3)
                }
            },
            panelOverlay: {
                friendAvatarOverlay
                    .padding(.leading, DiveBuddyDetailPresentation.avatarLeadingInset)
                    .offset(y: DiveBuddyDetailPresentation.avatarPanelOverlayVerticalOffset())
                    .accessibilityIdentifier("FriendProfile.AvatarOverlay")
            },
            pinnedContent: {
                pinnedSummary
            },
            panelContent: { bottomScrollInset, _ in
                FriendProfileContentPager(
                    lifetimeStats: lifetimeStats,
                    unitSystem: diveDisplayUnitSystem,
                    sharedActivityRows: sharedActivityRows,
                    sharedMediaItems: sharedMediaItems,
                    sharedMediaDiveByMediaID: sharedMediaDiveByMediaID,
                    isLoadingSharedContent: isLoadingSharedContent,
                    activityFilter: $activityFilter,
                    fullscreenSelectedMediaID: $fullscreenSelectedMediaID,
                    bottomScrollInset: bottomScrollInset,
                    onOpenDive: openSharedDive(id:),
                    onOpenActivityFromMedia: openSharedDiveFromMedia(_:)
                )
            },
            topChrome: { safeTop, topInset, _ in
                friendTopChrome(safeTop: safeTop, topInset: topInset)
            }
        )
        .hidesBottomTabBarWhenPushed()
        .navigationDestination(item: $selectedSharedDive) { dive in
            FriendSharedDiveDetailView(
                dive: dive,
                friendName: displayName,
                friendPhotoURL: photoURL,
                friendUID: friend.friendUID
            )
        }
        .task {
            await refreshProfile()
            try? await Task.sleep(for: PushedNavigationDeferralPresentation.afterPushMapDeferral)
            guard !Task.isCancelled else { return }
            showsDeferredFriendMap = true
            allowsHeroVideoAutoplay = true
        }
        .onChange(of: friendMapPins.count) { _, _ in
            syncFriendHeroMode()
        }
        .onChange(of: profile?.profileHeroURL) { _, _ in
            syncFriendHeroMode()
        }
        .onChange(of: sharedDives.count) { _, _ in
            syncFriendHeroMode()
        }
    }

    private func friendTopChrome(safeTop: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            BlueSheetTopChromeFadeLayer(
                safeTop: safeTop,
                topInset: topInset,
                style: .detailTop
            )

            AppHeader(
                title: "",
                showsBackButton: true,
                showsBrandWordmark: false,
                statusBarSafeAreaTop: safeTop,
                statusBarUsesListChromeFeather: BlueSheetTopChromePresentation.DetailTopFade.usesListStatusBarScrim
            )
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }

    private var friendAvatarOverlay: some View {
        FriendSharedMapOwnerAvatarView(
            displayName: displayName,
            photoURL: photoURL,
            diameter: Layout.avatarDiameter
        )
        .accessibilityHidden(false)
        .accessibilityLabel(
            "\(displayName), \(GoDiveUserAvatarPinPresentation.accessibilityLabel)"
        )
    }

    private var pinnedSummary: some View {
        BlueSheetPinnedSummary(
            accent: diveCountLabel,
            accentFont: BlueSheetPinnedSummaryPresentation.buddyAccentFont,
            accentAccessibilityIdentifier: "FriendProfile.DiveCount",
            title: displayName,
            titleFont: BlueSheetPinnedSummaryPresentation.buddyTitleFont,
            titleLineLimit: 2,
            titleMinimumScaleFactor: 0.85,
            accessibilityIdentifier: "FriendProfile.PinnedSummary",
            usesLeadingAccessoryLayout: true,
            contentVerticalOffset: DiveBuddyDetailPresentation.identityPinnedSummaryVerticalOffset,
            leadingAccessory: {
                Color.clear
                    .frame(
                        width: Layout.avatarDiameter,
                        height: Layout.avatarOverlapOffset
                    )
                    .accessibilityHidden(true)
            }
        )
    }

    private func openSharedDive(id: UUID) {
        selectedSharedDive = FriendProfileSharedDiveListPresentation.dive(
            matching: id,
            in: sharedDives
        )
    }

    private func openSharedDiveFromMedia(_ dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) {
        fullscreenSelectedMediaID = nil
        selectedSharedDive = dive
    }

    private func refreshProfile() async {
        isLoadingSharedContent = true
        async let profileTask = GoDiveFriendGraphService.fetchPublicProfile(uid: friend.friendUID)
        async let divesTask = GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(friendUID: friend.friendUID)
        let fetchedProfile = await profileTask
        let fetchedDives = await divesTask
        let commonNameByUUID = MarineLifeSpeciesResolver.commonNameByUUID(modelContext: modelContext)
        let dives = GoDiveSharedDiveProjectionSync.resolvingSightingDisplayNames(
            fetchedDives,
            modelContext: modelContext
        )

        let ownerID = accountSession.currentProfile?.id
        let togetherActivities: [DiveActivity]
        let catalogSites: [DiveSite]
        if let ownerID {
            togetherActivities = FriendProfileTogetherPresentation.togetherDiveActivities(
                friendUID: friend.friendUID,
                ownerProfileID: ownerID,
                modelContext: modelContext
            )
            catalogSites = DiveBuddyDetailPresentation.catalogSitesFromSharedDives(togetherActivities)
        } else {
            togetherActivities = []
            catalogSites = []
        }
        let togetherIDs = FriendProfileTogetherPresentation.togetherActivityIDs(from: togetherActivities)
        let mapPins = FriendProfileSharedDiveMapPresentation.pins(
            sharedDives: dives,
            togetherDives: togetherActivities,
            togetherActivityIDs: togetherIDs,
            catalogSites: catalogSites,
            currentFirebaseUID: currentFirebaseUID
        )
        let mediaItems = FriendProfileSharedMediaListPresentation.displayItems(from: dives)
        let mediaDiveMap = FriendProfileSharedMediaListPresentation.diveByMediaID(from: dives)
        let stats = FriendProfileLifetimeStatsPresentation.build(
            from: dives,
            commonNameByUUID: commonNameByUUID
        )

        await MainActor.run {
            profile = fetchedProfile
            sharedDives = dives
            sharedDiveCount = dives.count
            togetherDiveActivities = togetherActivities
            togetherActivityIDs = togetherIDs
            sharedMediaItems = mediaItems
            sharedMediaDiveByMediaID = mediaDiveMap
            lifetimeStats = stats
            friendMapPins = mapPins
            isLoadingSharedContent = false
            syncFriendHeroMode()
        }
    }

    private func syncFriendHeroMode() {
        friendHeroMode = PushedDetailHeroModePresentation.enforceModeWhenToggleHidden(
            friendHeroMode,
            hasAssociatedMedia: friendHasAssociatedMedia,
            hasMapContent: friendHasMapContent
        )
    }

    @ViewBuilder
    private func friendHeroBandContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        let hero = resolvedHero
        let heroFitLayout = context.mapFitLayout()
        let heroModeBinding = PushedDetailHeroModePresentation.heroModeBinding(
            hasAssociatedMedia: friendHasAssociatedMedia,
            hasMapContent: friendHasMapContent,
            mode: $friendHeroMode
        )

        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "FriendProfile.HeroBand") {
            FriendProfileHeroHeaderView(
                heroURL: hero?.url,
                mediaKind: hero?.kind,
                mapPins: showsDeferredFriendMap ? friendMapPins : [],
                mapFitLayout: heroFitLayout,
                isMapContentReady: showsDeferredFriendMap,
                shouldAutoPlayVideo: allowsHeroVideoAutoplay && hero?.kind == .video,
                selectedMode: heroModeBinding
            )
        }
    }
}
