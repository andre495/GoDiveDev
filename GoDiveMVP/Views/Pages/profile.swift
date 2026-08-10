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

        var id: Self { self }
    }

    @Environment(\.openTripPlanner) private var openTripPlanner
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNetworkConnectivityMonitor.self) private var networkConnectivity

    @Query private var ownedCertifications: [Certification]
    @Query private var ownedDiveActivities: [DiveActivity]
    @Query private var ownerDiveBuddies: [DiveBuddy]

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @State private var showsProfileEditSheet = false
    @State private var showsSideMenu = false
    @State private var activeInvite: FriendInviteSharePresentation?
    @State private var isCreatingInvite = false
    @State private var inviteStatusMessage: String?
    @State private var menuRoute: MenuRoute?
    @State private var profileAuxiliaryRoute: ProfileAuxiliaryRoute?
    @State private var profileHomeAggregate = HomeOverviewAggregate.empty
    @State private var marineLifeCatalog: [MarineLife] = []
    @State private var userDiveSites: [UserDiveSite] = []
    @State private var hasLoadedProfileNavigationCatalogs = false
    @State private var cachedTaggedMediaItems: [DiveMediaPhoto] = []
    @State private var cachedTaggedMediaTimeZoneOffsetByID: [UUID: Int?] = [:]
    @State private var cachedLinkedMediaItems: [TripDetailLinkedMediaItem] = []
    @State private var cachedTaggedMediaSightings: [SightingInstance] = []
    @State private var cachedMarineLifeCatalogForMedia: [MarineLife] = []
    @State private var hasLoadedTaggedMediaEnrichment = false
    @State private var observedSelfBuddyMediaTags: [DiveMediaBuddyTag] = []
    @State private var gallerySelectedMediaID: UUID?
    @State private var selfBuddyID: UUID?
    @State private var selfBuddyFeaturedTaggedMediaPhotoID: UUID?
    @State private var heroTaggedMediaID: UUID?
    @State private var allowsHeroVideoAutoplay = false
    @State private var profileHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var profileMapPins: [TripDetailMapPin] = []
    @State private var showsDeferredProfileMap = false
    @State private var diveSiteCatalog: [DiveSite] = []
    @State private var profileAggregateRebuildTask: Task<Void, Never>?
    @State private var profileEnrichmentTask: Task<Void, Never>?
    @State private var lastBuiltProfileStatsToken: String?
    @State private var lastProfileMapPinsToken: String?

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

    private var selfBuddyMediaTagsFingerprint: String {
        ProfileTaggedMediaPresentation.mediaTagIDsFingerprint(observedSelfBuddyMediaTags)
    }

    private var profileMapPinsToken: String {
        let owner = effectiveOwnerProfileID?.uuidString ?? "none"
        return "\(owner)|\(ownedDiveActivities.count)|\(diveSiteCatalog.count)"
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var ownedCertificationsFiltered: [Certification] {
        ownedCertifications
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
        observedSelfBuddyMediaTags
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        cachedTaggedMediaItems
    }

    private var displayHeroTaggedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: heroTaggedMediaID,
            in: cachedTaggedMediaItems
        )
    }

    private var expectsHeroTaggedMedia: Bool {
        !observedSelfBuddyMediaTags.isEmpty
    }

    private var profileHasAssociatedMedia: Bool {
        !cachedTaggedMediaItems.isEmpty
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
            if let selfBuddyID {
                ProfileSelfBuddyMediaTagsObserver(buddyID: selfBuddyID) { tags in
                    applyObservedSelfBuddyMediaTags(tags)
                }
            }

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
                onInviteBuddy: {
                    Task { await createInviteFromSideMenu() }
                },
                isInviteBuddyEnabled: networkConnectivity.isConnected && !isCreatingInvite
            )
            .zIndex(1)
        }
        .sheet(item: $activeInvite) { invite in
            FriendInviteShareSheet(inviteURL: invite.url)
        }
        .alert(
            "Invite unavailable",
            isPresented: Binding(
                get: { inviteStatusMessage != nil },
                set: { if !$0 { inviteStatusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                inviteStatusMessage = nil
            }
        } message: {
            Text(inviteStatusMessage ?? "")
        }
        .navigationDestination(item: $menuRoute) { route in
            menuDestinationView(for: route)
        }
        .navigationDestination(item: $profileAuxiliaryRoute) { route in
            profileAuxiliaryDestination(for: route)
        }
        .onChange(of: profileAuxiliaryRoute) { oldRoute, newRoute in
            let previousDiveIDs: Set<UUID> = {
                guard case .diveDetail(let id) = oldRoute else { return [] }
                return [id]
            }()
            let currentDiveIDs: Set<UUID> = {
                guard case .diveDetail(let id) = newRoute else { return [] }
                return [id]
            }()
            DiveActivityOverviewUIStatePresentation.discardSessionsLeavingStack(
                previousDiveIDs: previousDiveIDs,
                currentDiveIDs: currentDiveIDs
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
            if case .diveDetail(let id) = profileAuxiliaryRoute, id == activityID {
                profileAuxiliaryRoute = nil
            }
        }
        .sheet(isPresented: $showsProfileEditSheet) {
            if let profile = accountSession.currentProfile {
                ProfileEditSheet(profile: profile)
            }
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
            refreshProfileMapPinsIfNeeded()
            try? await Task.sleep(for: PushedNavigationDeferralPresentation.afterPushMapDeferral)
            guard !Task.isCancelled else { return }
            showsDeferredProfileMap = true
            allowsHeroVideoAutoplay = true
        }
        .task(id: profileStatsRebuildToken) {
            guard lastBuiltProfileStatsToken != profileStatsRebuildToken else { return }
            await rebuildProfileHomeAggregateAsync()
            guard !Task.isCancelled else { return }
            lastBuiltProfileStatsToken = profileStatsRebuildToken
        }
        .onChange(of: automaticallyRenumberDives) { _, _ in
            lastBuiltProfileStatsToken = nil
            scheduleProfileHomeAggregateRebuild()
        }
        .task(id: profileMapPinsToken) {
            refreshProfileMapPinsIfNeeded()
        }
        .task(id: effectiveOwnerProfileID) {
            guard diveSiteCatalog.isEmpty else {
                refreshProfileMapPinsIfNeeded()
                return
            }
            diveSiteCatalog = await DiveSiteCatalogLoader.loadSortedCatalog(modelContext: modelContext)
            guard !Task.isCancelled else { return }
            refreshProfileMapPinsIfNeeded()
        }
        .onChange(of: heroTaggedMediaID) { _, _ in
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: displayHeroTaggedMedia)
            syncProfileHeroMode()
        }
        .onChange(of: selfBuddyMediaTagsFingerprint) { _, _ in
            rebuildProfileTaggedMediaCaches(includeMarineLife: hasLoadedTaggedMediaEnrichment)
            syncHeroTaggedMediaSelection()
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: displayHeroTaggedMedia)
            syncProfileHeroMode()
        }
        .onChange(of: ownedDiveActivities.count) { _, _ in
            rebuildProfileTaggedMediaCaches(includeMarineLife: hasLoadedTaggedMediaEnrichment)
            syncHeroTaggedMediaSelection()
        }
        .onChange(of: selfBuddyID) { _, _ in
            observedSelfBuddyMediaTags = []
            cachedTaggedMediaItems = []
            syncSelfBuddyFeaturedMediaID()
            activateTaggedMediaScopeIfNeeded()
        }
        .onChange(of: profileMapPins.count) { _, _ in
            syncProfileHeroMode()
        }
        .onAppear {
            activateTaggedMediaScopeIfNeeded()
        }
        .onDisappear {
            cancelProfileBackgroundTasks()
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
            },
            titleTrailingAccessory: {
                profileEditEllipsisButton
            }
        )
    }

    private var profileEditEllipsisButton: some View {
        Button {
            showsProfileEditSheet = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ProfilePresentation.editProfileAccessibilityLabel)
        .accessibilityIdentifier(ProfilePresentation.editProfileAccessibilityIdentifier)
    }

    private func navigate(to route: MenuRoute) {
        NavigationStackPushCoalescing.assignUnlessDuplicate(route, to: &menuRoute)
    }

    @MainActor
    private func createInviteFromSideMenu() async {
        guard !isCreatingInvite else { return }
        guard networkConnectivity.isConnected else {
            inviteStatusMessage = GoDiveFriendsPresentation.firebaseUnavailableMessage
            return
        }

        withAnimation(.snappy(duration: 0.28)) {
            showsSideMenu = false
        }

        isCreatingInvite = true
        defer { isCreatingInvite = false }

        let result = await GoDiveFriendGraphService.createInvite()
        switch result {
        case .success(let pair):
            activeInvite = FriendInviteSharePresentation(token: pair.token, url: pair.url)
            inviteStatusMessage = nil
        case .failure(let failure):
            inviteStatusMessage = failure.message
        }
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

    private func applyObservedSelfBuddyMediaTags(_ tags: [DiveMediaBuddyTag]) {
        let nextFingerprint = ProfileTaggedMediaPresentation.mediaTagIDsFingerprint(tags)
        let currentFingerprint = ProfileTaggedMediaPresentation.mediaTagIDsFingerprint(
            observedSelfBuddyMediaTags
        )
        guard nextFingerprint != currentFingerprint else { return }
        observedSelfBuddyMediaTags = tags
    }

    private func syncHeroTaggedMediaSelection() {
        let photos = cachedTaggedMediaItems
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
            lifetimeStatsContentFingerprint: profileHomeAggregate.contentFingerprint,
            unitSystem: diveDisplayUnitSystem,
            onOpenLeaderboard: {
                NavigationStackPushCoalescing.assignUnlessDuplicate(
                    .lifetimeStatsLeaderboard($0),
                    to: &profileAuxiliaryRoute
                )
            },
            certifications: CertificationPresentation.sortedForList(ownedCertificationsFiltered),
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

    private func openProfileDive(_ diveID: UUID) {
        NavigationStackPushCoalescing.assignUnlessDuplicate(.diveDetail(diveID), to: &profileAuxiliaryRoute)
    }

    private func handleProfilePagerPageFirstMounted(_ page: ProfileDetailContentPage) {
        switch page {
        case .taggedMedia:
            guard !hasLoadedTaggedMediaEnrichment else { return }
            hasLoadedTaggedMediaEnrichment = true
            rebuildProfileTaggedMediaCaches(includeMarineLife: true)
            scheduleProfileEnrichmentLoad {
                await loadProfileMarineLifeCatalogForMediaIfNeeded()
            }
        case .diverStats:
            break
        }
    }

    private func scheduleProfileHomeAggregateRebuild() {
        profileAggregateRebuildTask?.cancel()
        profileAggregateRebuildTask = Task { @MainActor in
            await rebuildProfileHomeAggregateAsync()
        }
    }

    private func scheduleProfileEnrichmentLoad(_ work: @escaping @MainActor () async -> Void) {
        profileEnrichmentTask?.cancel()
        profileEnrichmentTask = Task { @MainActor in
            await work()
        }
    }

    private func cancelProfileBackgroundTasks() {
        profileAggregateRebuildTask?.cancel()
        profileAggregateRebuildTask = nil
        profileEnrichmentTask?.cancel()
        profileEnrichmentTask = nil
    }

    @MainActor
    private func rebuildProfileHomeAggregateAsync() async {
        if marineLifeCatalog.isEmpty {
            await reloadProfileNavigationCatalogsIfNeeded()
        }
        guard !Task.isCancelled else { return }
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
        guard !Task.isCancelled else { return }
        profileHomeAggregate = built
        lastBuiltProfileStatsToken = profileStatsRebuildToken
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
        let tags = observedSelfBuddyMediaTags
        let ownerIDs = ownerDiveActivityIDs
        let media = DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            tags: tags,
            ownerDiveActivityIDs: ownerIDs,
            modelContext: modelContext
        )
        cachedTaggedMediaItems = media

        let offsetByActivityID = Dictionary(
            godiveUniquingKeysWithValues: ownedDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
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
                onOpenDive: {
                    NavigationStackPushCoalescing.assignUnlessDuplicate(
                        .diveDetail($0),
                        to: &profileAuxiliaryRoute
                    )
                },
                onOpenSite: { _ in },
                onOpenSpecies: { _ in }
            )
        case .diveDetail(let id):
            if let activity = ownedDiveActivities.first(where: { $0.id == id }) {
                ViewSingleActivity(activity: activity)
            } else {
                ActivityMissingDestinationPopView {
                    if case .diveDetail(let routeID) = profileAuxiliaryRoute, routeID == id {
                        profileAuxiliaryRoute = nil
                    }
                }
            }
        }
    }

    private func refreshProfileMapPinsIfNeeded() {
        let token = profileMapPinsToken
        guard lastProfileMapPinsToken != token else { return }
        profileMapPins = ProfileDetailMapPresentation.pins(
            from: ownedDiveActivities,
            catalogSites: diveSiteCatalog
        )
        lastProfileMapPinsToken = token
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
