import SwiftUI

/// Friend’s public profile — mirrors owner **Profile** chrome; sheet panel is intentionally empty.
struct FriendProfileView: View {
    let friend: GoDiveFriendGraphService.FriendEdge

    @State private var profile: GoDiveFriendGraphService.PublicProfileSummary?
    @State private var sharedDiveCount: Int?
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

    private var heroURL: URL? {
        let raw = profile?.profileHeroURL ?? friend.profileHeroURL
        guard let raw else { return nil }
        return GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: raw)
    }

    private var heroKind: GoDiveProfileHeroMediaKind? {
        profile?.profileHeroMediaKind ?? friend.profileHeroMediaKind
    }

    private var friendHasRemoteHeroMedia: Bool {
        heroURL != nil && heroKind != nil
    }

    private var friendHasMapContent: Bool {
        !friendMapPins.isEmpty
    }

    private var showsFriendHeroModeToggle: Bool {
        PushedDetailHeroModePresentation.showsModeToggle(
            hasAssociatedMedia: friendHasRemoteHeroMedia,
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
            panelContent: { _, _ in
                Color.clear
                    .frame(minHeight: 120)
                    .accessibilityHidden(true)
            },
            topChrome: { safeTop, topInset, _ in
                friendTopChrome(safeTop: safeTop, topInset: topInset)
            }
        )
        .hidesBottomTabBarWhenPushed()
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
            ) {
                NavigationLink {
                    FriendSharedLogbookView(friend: friend)
                } label: {
                    Image(systemName: "book.closed")
                        .appToolbarIconButtonLabel()
                }
                .appStandaloneIconButtonStyle()
                .accessibilityLabel(FriendProfilePresentation.sharedLogbookToolbarAccessibilityLabel)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }

    @ViewBuilder
    private var friendAvatarOverlay: some View {
        if let photoURL,
           let url = GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: photoURL)
        {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    friendAvatarPlaceholder
                }
            }
            .frame(width: Layout.avatarDiameter, height: Layout.avatarDiameter)
            .clipShape(Circle())
            .overlay {
                ProfileAvatarChrome.accentRingOverlay(diameter: Layout.avatarDiameter)
            }
        } else {
            friendAvatarPlaceholder
        }
    }

    private var friendAvatarPlaceholder: some View {
        ProfileAvatarView(
            profilePhoto: nil,
            diameter: Layout.avatarDiameter,
            iconFont: .system(size: 56),
            placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
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

    private func refreshProfile() async {
        async let profileTask = GoDiveFriendGraphService.fetchPublicProfile(uid: friend.friendUID)
        async let divesTask = GoDiveSharedDiveProjectionSync.fetchFriendSharedDives(friendUID: friend.friendUID)
        let fetchedProfile = await profileTask
        let dives = await divesTask
        let mapPins = FriendProfileSharedDiveMapPresentation.pins(from: dives)
        await MainActor.run {
            profile = fetchedProfile
            sharedDiveCount = dives.count
            friendMapPins = mapPins
            syncFriendHeroMode()
        }
    }

    private func syncFriendHeroMode() {
        friendHeroMode = PushedDetailHeroModePresentation.enforceModeWhenToggleHidden(
            friendHeroMode,
            hasAssociatedMedia: friendHasRemoteHeroMedia,
            hasMapContent: friendHasMapContent
        )
    }

    @ViewBuilder
    private func friendHeroBandContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        let heroFitLayout = context.mapFitLayout()
        let heroModeBinding = PushedDetailHeroModePresentation.heroModeBinding(
            hasAssociatedMedia: friendHasRemoteHeroMedia,
            hasMapContent: friendHasMapContent,
            mode: $friendHeroMode
        )

        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "FriendProfile.HeroBand") {
            FriendProfileHeroHeaderView(
                heroURL: heroURL,
                mediaKind: heroKind,
                mapPins: showsDeferredFriendMap ? friendMapPins : [],
                mapFitLayout: heroFitLayout,
                isMapContentReady: showsDeferredFriendMap,
                shouldAutoPlayVideo: allowsHeroVideoAutoplay && heroKind == .video,
                selectedMode: heroModeBinding
            )
        }
    }
}
