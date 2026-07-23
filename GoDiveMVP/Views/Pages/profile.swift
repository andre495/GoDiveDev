import SwiftData
import SwiftUI

struct ProfileView: View {
    private enum Layout {
        static let avatarDiameter = DiveBuddyDetailPresentation.profileAvatarDiameter
        static let avatarOverlapOffset = DiveBuddyDetailPresentation.avatarOverlapOffset()
    }

    private enum MenuRoute: Hashable, Identifiable {
        case settings
        case certifications
        case equipment
        case diveBuddies

        var id: Self { self }
    }

    private enum ProfileAuxiliaryRoute: Hashable, Identifiable {
        case lifetimeStatsLeaderboard(HomeLifetimeStatsLeaderboardKind)
        case diveDetail(UUID)
        case diveBuddy(UUID)

        var id: Self { self }
    }

    @Environment(\.openTripPlanner) private var openTripPlanner
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var ownedCertifications: [Certification]
    @Query private var ownedDiveActivities: [DiveActivity]
    @Query private var ownerDiveBuddies: [DiveBuddy]

    @Query(sort: [SortDescriptor(\DiveMediaBuddyTag.id, order: .forward)])
    private var buddyMediaTags: [DiveMediaBuddyTag]

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @State private var showsProfileEditSheet = false
    @State private var showsSignOutConfirmation = false
    @State private var showsSideMenu = false
    @State private var menuRoute: MenuRoute?
    @State private var profileAuxiliaryRoute: ProfileAuxiliaryRoute?
    @State private var profileHomeAggregate = HomeOverviewAggregate.empty
    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var userDiveSites: [UserDiveSite] = []
    @State private var hasLoadedProfileNavigationCatalogs = false
    @State private var cachedTaggedMediaTimeZoneOffsetByID: [UUID: Int?] = [:]
    @State private var cachedLinkedMediaItems: [TripDetailLinkedMediaItem] = []
    @State private var cachedTaggedMediaSightings: [SightingInstance] = []
    @State private var cachedMarineLifeCatalogForMedia: [MarineLife] = []
    @State private var hasLoadedTaggedMediaEnrichment = false
    @State private var gallerySelectedMediaID: UUID?
    @State private var selfBuddyID: UUID?
    @State private var selfBuddyFeaturedTaggedMediaPhotoID: UUID?
    @State private var heroTaggedMediaID: UUID?
    @State private var allowsHeroVideoAutoplay = false
    @State private var profileHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var profileMapPins: [TripDetailMapPin] = []
    @State private var showsDeferredProfileMap = false
    @State private var diveSiteCatalog: [DiveSite] = []

    private let ownerProfileID: UUID?

    init(ownerProfileID: UUID?) {
        self.ownerProfileID = ownerProfileID
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownedCertifications = Query(
            filter: #Predicate<Certification> { $0.ownerProfileID == filterOwnerID },
            sort: [SortDescriptor(\Certification.dateAttained, order: .reverse)]
        )
        _ownedDiveActivities = Query(
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

    private var effectiveOwnerProfileID: UUID? {
        ownerProfileID ?? accountSession.currentProfile?.id
    }

    private var profileStatsRebuildToken: String {
        let profileID = accountSession.currentProfile?.id.uuidString ?? "none"
        return "\(ownedDiveActivities.count)-\(automaticallyRenumberDives)-\(profileID)"
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownedCertificationsFiltered: [Certification] {
        ownedCertifications
    }

    private var profileFeaturedCertification: CertificationPresentation.ProfileFeaturedCertificationDisplay? {
        CertificationPresentation.profileFeaturedCertification(from: ownedCertificationsFiltered)
    }

    private var featuredCertificationCard: Certification? {
        CertificationPresentation.profileFeaturedCertificationCard(from: ownedCertificationsFiltered)
    }

    private var diveCountLabel: String {
        ProfilePresentation.diveActivityCountLabel(
            DiveActivityDiveNumbering.numberedDiveCount(in: ownedDiveActivities)
        )
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownedDiveActivities.map(\.id))
    }

    private var selfBuddyTags: [DiveMediaBuddyTag] {
        guard let selfBuddyID else { return [] }
        return buddyMediaTags.filter { $0.buddyID == selfBuddyID }
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            tags: selfBuddyTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )
    }

    private var displayHeroTaggedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: heroTaggedMediaID,
            in: taggedMediaItems
        )
    }

    private var expectsHeroTaggedMedia: Bool {
        !selfBuddyTags.isEmpty
    }

    private var profileHasAssociatedMedia: Bool {
        !taggedMediaItems.isEmpty
    }

    private var profileHasMapContent: Bool {
        !profileMapPins.isEmpty
    }

    private var showsProfileHeroModeToggle: Bool {
        PushedDetailHeroModePresentation.showsModeToggle(
            hasAssociatedMedia: profileHasAssociatedMedia,
            hasMapContent: profileHasMapContent
        )
    }

    var body: some View {
        ZStack {
            BlueSheetDetailPage(
                configuration: DiveBuddyDetailPresentation.identityBlueSheetPageConfiguration(
                    accessibilityRootIdentifier: "Profile.Root",
                    usesProfileBubblePanelBackground: true
                ),
                hero: { context in
                    DiveBuddyDetailHeroHeaderView(
                        media: displayHeroTaggedMedia,
                        mapPins: showsDeferredProfileMap ? profileMapPins : [],
                        mapFitLayout: context.mapFitLayout(),
                        height: context.heroHeight,
                        expectsTaggedMedia: expectsHeroTaggedMedia,
                        isMapContentReady: showsDeferredProfileMap,
                        shouldAutoPlaySelectedVideo: allowsHeroVideoAutoplay
                            && DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(
                                for: displayHeroTaggedMedia
                            ),
                        style: .profile,
                        onSiteSelected: { _ in },
                        selectedMode: PushedDetailHeroModePresentation.heroModeBinding(
                            hasAssociatedMedia: profileHasAssociatedMedia,
                            hasMapContent: profileHasMapContent,
                            mode: $profileHeroMode
                        )
                    )
                },
                heroOverlay: { _ in
                    if showsProfileHeroModeToggle {
                        PushedDetailHeroModeToggle(
                            selectedMode: $profileHeroMode,
                            accessibilityIdentifierPrefix: "Profile.Hero.ModeToggle"
                        )
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                    }
                },
                panelOverlay: {
                    profileAvatarOverlay
                        .padding(.leading, DiveBuddyDetailPresentation.avatarLeadingInset)
                        .offset(y: DiveBuddyDetailPresentation.avatarPanelOverlayVerticalOffset())
                        .accessibilityIdentifier("Profile.AvatarOverlay")
                },
                pinnedContent: {
                    profilePinnedSummary
                },
                panelContent: { bottomScrollInset, _ in
                    profileContentPager(bottomScrollInset: bottomScrollInset)
                },
                topChrome: { safeTop, topInset, _ in
                    profileTopChrome(safeTop: safeTop, topInset: topInset)
                }
            )

            ProfileSideMenuOverlay(
                isPresented: showsSideMenu,
                onDismiss: {
                    withAnimation(.snappy(duration: 0.28)) {
                        showsSideMenu = false
                    }
                },
                onEditProfile: {
                    withAnimation(.snappy(duration: 0.28)) {
                        showsSideMenu = false
                    }
                    showsProfileEditSheet = true
                },
                onSettings: {
                    navigate(to: .settings)
                },
                onCertifications: {
                    navigate(to: .certifications)
                },
                onEquipment: {
                    navigate(to: .equipment)
                },
                onBuddies: {
                    navigate(to: .diveBuddies)
                },
                onTrips: {
                    withAnimation(.snappy(duration: 0.28)) {
                        showsSideMenu = false
                    }
                    openTripPlanner?()
                },
                onSignOut: {
                    withAnimation(.snappy(duration: 0.28)) {
                        showsSideMenu = false
                    }
                    showsSignOutConfirmation = true
                }
            )
            .zIndex(1)
        }
        .navigationDestination(item: $menuRoute) { route in
            menuDestinationView(for: route)
        }
        .navigationDestination(item: $profileAuxiliaryRoute) { route in
            profileAuxiliaryDestination(for: route)
        }
        .sheet(isPresented: $showsProfileEditSheet) {
            if let profile = accountSession.currentProfile {
                ProfileEditSheet(profile: profile)
            }
        }
        .alert(
            ProfilePresentation.signOutConfirmationTitle,
            isPresented: $showsSignOutConfirmation
        ) {
            Button(ProfilePresentation.signOutCancelButtonTitle, role: .cancel) {}
            Button(ProfilePresentation.signOutConfirmButtonTitle, role: .destructive) {
                accountSession.signOut()
                dismiss()
            }
        } message: {
            Text(ProfilePresentation.signOutConfirmationMessage)
        }
        .task(id: accountSession.currentProfile?.id) {
            selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
            syncSelfBuddyFeaturedMediaID()
            syncHeroTaggedMediaSelection()
            rebuildProfileTaggedMediaCaches(includeMarineLife: hasLoadedTaggedMediaEnrichment)
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: displayHeroTaggedMedia)
            refreshProfileMapPins()
            try? await Task.sleep(for: PushedNavigationDeferralPresentation.afterPushMapDeferral)
            guard !Task.isCancelled else { return }
            showsDeferredProfileMap = true
            allowsHeroVideoAutoplay = true
        }
        .task(id: profileStatsRebuildToken) {
            await rebuildProfileHomeAggregateAsync()
        }
        .onChange(of: automaticallyRenumberDives) { _, _ in
            Task { await rebuildProfileHomeAggregateAsync() }
        }
        .task(id: ownedDiveActivities.count) {
            refreshProfileMapPins()
        }
        .task {
            diveSiteCatalog = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
            refreshProfileMapPins()
        }
        .onChange(of: heroTaggedMediaID) { _, _ in
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: displayHeroTaggedMedia)
            syncProfileHeroMode()
        }
        .onChange(of: taggedMediaItems.map(\.id)) { _, _ in
            rebuildProfileTaggedMediaCaches(includeMarineLife: hasLoadedTaggedMediaEnrichment)
            syncHeroTaggedMediaSelection()
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: displayHeroTaggedMedia)
            syncProfileHeroMode()
        }
        .onChange(of: selfBuddyID) { _, _ in
            syncSelfBuddyFeaturedMediaID()
            rebuildProfileTaggedMediaCaches(includeMarineLife: hasLoadedTaggedMediaEnrichment)
            activateTaggedMediaScopeIfNeeded()
        }
        .onChange(of: profileMapPins.count) { _, _ in
            syncProfileHeroMode()
        }
        .onAppear {
            activateTaggedMediaScopeIfNeeded()
        }
        .onDisappear {
            deactivateTaggedMediaScopeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: GoDiveFirebaseCloudMessaging.openFriendsListNotification)) { _ in
            navigate(to: .diveBuddies)
        }
    }

    private func profileTopChrome(safeTop: CGFloat, topInset: CGFloat) -> some View {
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
                profileMenuButton
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .zIndex(1)
        }
    }

    private var profileMenuButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.28)) {
                showsSideMenu = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: ProfilePresentation.menuIconPointSize, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.headerChromeIconForeground)
                .frame(
                    width: SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension,
                    height: SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ProfilePresentation.menuAccessibilityLabel)
        .accessibilityIdentifier("Profile.MenuButton")
    }

    @ViewBuilder
    private var profileAvatarOverlay: some View {
        if let profile = accountSession.currentProfile {
            ProfileAvatarEditor(diameter: Layout.avatarDiameter, profile: profile)
        } else {
            ProfileAvatarView(
                profilePhoto: nil,
                diameter: Layout.avatarDiameter,
                iconFont: .system(size: 56)
            )
        }
    }

    private var profilePinnedSummary: some View {
        BlueSheetPinnedSummary(
            accent: diveCountLabel,
            accentFont: BlueSheetPinnedSummaryPresentation.buddyAccentFont,
            accentAccessibilityIdentifier: "Profile.DiveCount",
            title: accountSession.currentProfile?.displayName ?? UserProfileStore.defaultDisplayName,
            titleFont: BlueSheetPinnedSummaryPresentation.buddyTitleFont,
            titleLineLimit: 2,
            titleMinimumScaleFactor: 0.85,
            accessibilityIdentifier: "Profile.PinnedSummary",
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

    private func navigate(to route: MenuRoute) {
        menuRoute = route
    }

    @ViewBuilder
    private func menuDestinationView(for route: MenuRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .certifications:
            CertificationsListView()
        case .equipment:
            EquipmentLockerView()
        case .diveBuddies:
            DiveBuddiesListView(ownerProfileID: ownerProfileID)
        }
    }

    private func syncHeroTaggedMediaSelection() {
        let photos = taggedMediaItems
        guard !photos.isEmpty else {
            heroTaggedMediaID = nil
            return
        }
        heroTaggedMediaID = DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: selfBuddyFeaturedTaggedMediaPhotoID,
            sessionRandomID: heroTaggedMediaID
        )
    }

    @ViewBuilder
    private func profileContentPager(bottomScrollInset: CGFloat) -> some View {
        ProfileDetailContentPager(
            lifetimeStats: profileHomeAggregate.lifetimeStats,
            myActivitiesSummary: profileHomeAggregate.myActivitiesSummary,
            buddyLeaderboard: profileHomeAggregate.buddyLeaderboard,
            lifetimeStatsContentFingerprint: profileHomeAggregate.contentFingerprint,
            unitSystem: diveDisplayUnitSystem,
            onOpenLeaderboard: { profileAuxiliaryRoute = .lifetimeStatsLeaderboard($0) },
            onOpenBuddy: openProfileBuddyFromStats,
            danInsuranceNumber: accountSession.currentProfile?.danInsuranceNumber,
            featuredCertification: featuredCertificationCard,
            featuredCertificationDisplay: profileFeaturedCertification,
            certificationCount: ownedCertificationsFiltered.count,
            onViewAllCertifications: { navigate(to: .certifications) },
            taggedMediaItems: taggedMediaItems,
            taggedMediaTimeZoneOffsetByID: cachedTaggedMediaTimeZoneOffsetByID,
            linkedMediaItems: cachedLinkedMediaItems,
            mediaSightings: cachedTaggedMediaSightings,
            marineLifeCatalog: cachedMarineLifeCatalogForMedia,
            ownerProfileID: effectiveOwnerProfileID,
            featuredTaggedMediaPhotoID: selfBuddyFeaturedTaggedMediaPhotoID,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            onToggleFeaturedTaggedMedia: toggleProfileFeaturedTaggedMedia,
            onOpenDive: openProfileDive,
            bottomScrollInset: bottomScrollInset,
            onPageFirstMounted: handleProfilePagerPageFirstMounted
        )
    }

    private func openProfileBuddyFromStats(buddyID: UUID) {
        guard !DiveBuddySelfRepresentation.isSelfBuddyID(buddyID, selfBuddyID: selfBuddyID) else { return }
        profileAuxiliaryRoute = .diveBuddy(buddyID)
    }

    private func openProfileDive(_ diveID: UUID) {
        profileAuxiliaryRoute = .diveDetail(diveID)
    }

    private func handleProfilePagerPageFirstMounted(_ page: ProfileDetailContentPage) {
        switch page {
        case .taggedMedia:
            guard !hasLoadedTaggedMediaEnrichment else { return }
            hasLoadedTaggedMediaEnrichment = true
            rebuildProfileTaggedMediaCaches(includeMarineLife: true)
            Task { await loadProfileMarineLifeCatalogForMediaIfNeeded() }
        case .diverStats, .details:
            break
        }
    }

    @MainActor
    private func rebuildProfileHomeAggregateAsync() async {
        if marineLifeCatalog.isEmpty {
            await reloadProfileNavigationCatalogsIfNeeded()
        }
        let ownerProfile = accountSession.currentProfile
        let built = await HomeOverviewAggregateBuilder.buildAsync(
            activities: ownedDiveActivities,
            marineLifeCatalog: marineLifeCatalog,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: diveDisplayUnitSystem,
            ownerProfileID: effectiveOwnerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext
        )
        profileHomeAggregate = built
    }

    private func reloadProfileNavigationCatalogsIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedProfileNavigationCatalogs || marineLifeCatalog.isEmpty else { return }
        let container = modelContext.container
        async let marineLifeIDs = MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
        marineLifeCatalog = MarineLifeCatalogLoader.bindModels(
            persistentIDs: await marineLifeIDs,
            modelContext: modelContext
        )
        if let effectiveOwnerProfileID {
            let ownerID = effectiveOwnerProfileID
            userDiveSites = (try? modelContext.fetch(
                FetchDescriptor<UserDiveSite>(
                    predicate: #Predicate { $0.ownerProfileID == ownerID },
                    sortBy: [SortDescriptor(\.siteName)]
                )
            )) ?? []
        } else {
            userDiveSites = []
        }
        guard !Task.isCancelled else { return }
        hasLoadedProfileNavigationCatalogs = true
    }

    private func loadProfileMarineLifeCatalogForMediaIfNeeded() async {
        guard cachedMarineLifeCatalogForMedia.isEmpty else { return }
        let container = modelContext.container
        let marineLifeIDs = await MarineLifeCatalogLoader.fetchSortedPersistentIDs(container: container)
        cachedMarineLifeCatalogForMedia = MarineLifeCatalogLoader.bindModels(
            persistentIDs: marineLifeIDs,
            modelContext: modelContext
        )
        rebuildProfileTaggedMediaCaches(includeMarineLife: true)
    }

    private func rebuildProfileTaggedMediaCaches(includeMarineLife: Bool) {
        let tags = selfBuddyTags
        let ownerIDs = ownerDiveActivityIDs
        let media = taggedMediaItems

        let offsetByActivityID = Dictionary(
            uniqueKeysWithValues: ownedDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        cachedTaggedMediaTimeZoneOffsetByID = DiveBuddyTaggedMediaPresentation.timeZoneOffsetByMediaID(
            tags: tags,
            ownerDiveActivityIDs: ownerIDs,
            timeZoneOffsetByActivityID: offsetByActivityID
        )
        cachedLinkedMediaItems = DiveBuddyTaggedMediaPresentation.linkedMediaItems(
            tags: tags,
            ownerDiveActivityIDs: ownerIDs,
            mediaItems: media
        )

        if includeMarineLife, !media.isEmpty {
            let taggedMediaIDs = Set(media.map(\.id))
            let sightings = (try? MarineLifeSightingRecorder.sightings(
                forMediaPhotoIDs: taggedMediaIDs,
                modelContext: modelContext
            )) ?? []
            cachedTaggedMediaSightings = DiveBuddyTaggedMediaPresentation.sightingsForTaggedMedia(
                allSightings: sightings,
                taggedMediaItemIDs: taggedMediaIDs
            )
        } else if !includeMarineLife {
            cachedTaggedMediaSightings = []
        }
    }

    private func syncSelfBuddyFeaturedMediaID() {
        guard let selfBuddyID else {
            selfBuddyFeaturedTaggedMediaPhotoID = nil
            return
        }
        selfBuddyFeaturedTaggedMediaPhotoID = ownerDiveBuddies
            .first(where: { $0.id == selfBuddyID })?
            .featuredTaggedMediaPhotoID
    }

    private func toggleProfileFeaturedTaggedMedia() {
        guard let selfBuddyID,
              let buddy = ownerDiveBuddies.first(where: { $0.id == selfBuddyID }),
              let selectedID = gallerySelectedMediaID,
              taggedMediaItems.contains(where: { $0.id == selectedID })
        else { return }

        let nextFeaturedID = DiveBuddyTaggedMediaPresentation.toggledFeaturedMediaPhotoID(
            mediaID: selectedID,
            explicitFeaturedID: buddy.featuredTaggedMediaPhotoID
        )
        try? DiveBuddyFeaturedMediaStorage.setFeaturedTaggedMedia(
            nextFeaturedID,
            on: buddy,
            modelContext: modelContext
        )
        selfBuddyFeaturedTaggedMediaPhotoID = nextFeaturedID

        if let nextFeaturedID {
            heroTaggedMediaID = nextFeaturedID
        } else {
            heroTaggedMediaID = DiveBuddyHeroMediaSession.pickNewRandomHeroMediaID(
                buddyID: buddy.id,
                in: taggedMediaItems
            )
        }

        GoDiveProfileHeroFeaturedMediaSync.scheduleSyncForSelfBuddyHeader(
            buddy: buddy,
            owner: accountSession.currentProfile,
            sessionRandomHeroMediaID: heroTaggedMediaID,
            modelContext: modelContext,
            force: true
        )
    }

    @ViewBuilder
    private func profileAuxiliaryDestination(for route: ProfileAuxiliaryRoute) -> some View {
        switch route {
        case .lifetimeStatsLeaderboard(let kind):
            HomeLifetimeStatsLeaderboardView(
                kind: kind,
                diveStatsInputs: profileHomeAggregate.diveStatsInputs,
                activities: ownedDiveActivities,
                diveSites: diveSiteCatalog,
                userDiveSites: userDiveSites,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: diveDisplayUnitSystem,
                automaticallyRenumberDives: automaticallyRenumberDives,
                sightings: profileHomeAggregate.sightingCountInputs,
                onOpenDive: { profileAuxiliaryRoute = .diveDetail($0) },
                onOpenSite: { _ in },
                onOpenSpecies: { _ in }
            )
        case .diveDetail(let id):
            if let activity = ownedDiveActivities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                Text("This dive is no longer in your log.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        case .diveBuddy(let buddyID):
            if let buddy = ownerDiveBuddies.first(where: { $0.id == buddyID }) {
                DiveBuddyOrFriendDetailView(buddy: buddy)
                    .hidesBottomTabBarWhenPushed()
            } else {
                Text("This buddy is no longer on your roster.")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding()
            }
        }
    }

    private func refreshProfileMapPins() {
        profileMapPins = ProfileDetailMapPresentation.pins(
            from: ownedDiveActivities,
            catalogSites: diveSiteCatalog
        )
        syncProfileHeroMode()
    }

    private func syncProfileHeroMode() {
        profileHeroMode = PushedDetailHeroModePresentation.enforceModeWhenToggleHidden(
            profileHeroMode,
            hasAssociatedMedia: profileHasAssociatedMedia,
            hasMapContent: profileHasMapContent
        )
    }

    private func activateTaggedMediaScopeIfNeeded() {
        guard let selfBuddyID else { return }
        DiveMediaScopeCache.shared.activateScope(.buddyDetail(selfBuddyID))
    }

    private func deactivateTaggedMediaScopeIfNeeded() {
        guard let selfBuddyID else { return }
        DiveMediaScopeCache.shared.deactivateScope(.buddyDetail(selfBuddyID))
    }
}

#Preview {
    NavigationStack {
        ProfileView(ownerProfileID: nil)
    }
    .environment(AccountSession.shared)
    .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
