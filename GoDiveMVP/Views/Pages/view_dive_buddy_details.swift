import Contacts
import SwiftData
import SwiftUI

/// Buddy roster detail — pushed (not a sheet) from **`DiveBuddiesListView`**.
struct ViewDiveBuddyDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openCatalogDiveSiteDetail) private var openCatalogDiveSiteDetail

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Bindable var buddy: DiveBuddy

    @Query private var buddyDiveTags: [DiveBuddyTag]

    @Query private var buddyMediaTags: [DiveMediaBuddyTag]

    @State private var cachedMarineLifeCatalog: [MarineLife] = []
    @State private var showsEditSheet = false
    @State private var showsContactPicker = false
    @State private var contactsAccessError: String?
    @State private var contactLinkError: String?
    @State private var cachedSharedDiveCount = 0
    @State private var cachedDiveRows: [DiveLogbookRowDisplayData] = []
    @State private var cachedSharedDiveActivities: [DiveActivity] = []
    @State private var ownerNumberingRows: [DiveActivityDiveNumbering.NumberingRow] = []
    @State private var ownerActivityTimeZoneOffsets: [UUID: Int?] = [:]
    @State private var showsDeferredBuddyChrome = false
    @State private var cachedTripRows: [DiveBuddyTripRowDisplayData] = []
    @State private var cachedTaggedMediaItems: [DiveMediaPhoto] = []
    @State private var cachedTaggedMediaTimeZoneOffsetByID: [UUID: Int?] = [:]
    @State private var cachedLinkedMediaItems: [TripDetailLinkedMediaItem] = []
    @State private var cachedMapPins: [TripDetailMapPin] = []
    @State private var cachedCatalogSites: [DiveSite] = []
    @State private var cachedTaggedMediaSightings: [SightingInstance] = []
    @State private var heroTaggedMediaID: UUID?
    @State private var gallerySelectedMediaID: UUID?
    @State private var buddyDiveNavigationID: BuddyDiveNavigationID?
    @State private var buddySiteNavigationID: UUID?
    @State private var buddyHeroMode: DiveBuddyDetailHeroHeaderView.Mode = .media
    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback
    @State private var layoutSafeAreaTopFloor = DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
    @State private var layoutViewportHeightFloor = DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor()

    private struct BuddyDiveNavigationID: Identifiable, Hashable {
        let id: UUID
    }

    init(buddy: DiveBuddy) {
        self.buddy = buddy
        let buddyID = buddy.id
        _buddyDiveTags = Query(
            filter: #Predicate<DiveBuddyTag> { $0.buddyID == buddyID },
            sort: [SortDescriptor(\.id, order: .forward)]
        )
        _buddyMediaTags = Query(
            filter: #Predicate<DiveMediaBuddyTag> { $0.buddyID == buddyID },
            sort: [SortDescriptor(\.id, order: .forward)]
        )
        _heroTaggedMediaID = State(
            initialValue: DiveBuddyDetailPresentation.initialHeroTaggedMediaPhotoID(for: buddy)
        )

        let initialMediaTags = Array(buddy.mediaBuddyTags)
        let initialTaggedPhotos = DiveBuddyTaggedMediaPresentation.photosAvailableFromTagRelationships(
            initialMediaTags
        )
        _cachedTaggedMediaItems = State(initialValue: initialTaggedPhotos)

        let initialSharedDiveContent = DiveBuddyDetailPresentation.initialSharedDiveContent(for: buddy)
        _cachedDiveRows = State(initialValue: initialSharedDiveContent.rows)
        _cachedSharedDiveActivities = State(initialValue: initialSharedDiveContent.sharedDives)
        _cachedSharedDiveCount = State(initialValue: initialSharedDiveContent.sharedDives.count)
    }

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownerDiveActivitiesForLayout: [DiveActivity] {
        cachedSharedDiveActivities
    }

    private var ownerDiveIDsForLayout: Set<UUID> {
        if !ownerNumberingRows.isEmpty {
            return Set(ownerNumberingRows.map(\.id))
        }
        return Set(cachedSharedDiveActivities.map(\.id))
    }

    private var homeLayoutSeamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
    }

    private var homeAlignedStatsPanelContentHeight: CGFloat {
        homeLayoutSeamInputs.statsPanelContentHeight
    }

    private var effectiveBuddyDiveTags: [DiveBuddyTag] {
        DiveBuddyDetailPresentation.effectiveDiveTags(
            queried: buddyDiveTags,
            relationship: Array(buddy.diveParticipations)
        )
    }

    private var effectiveBuddyMediaTags: [DiveMediaBuddyTag] {
        DiveBuddyDetailPresentation.effectiveMediaTags(
            queried: buddyMediaTags,
            relationship: Array(buddy.mediaBuddyTags)
        )
    }

    private var headerSharedDiveCount: Int {
        max(cachedSharedDiveCount, effectiveBuddyDiveTags.count)
    }

    private var heroTaggedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: heroTaggedMediaID,
            in: cachedTaggedMediaItems
        )
    }

    private var buddyHeaderTaggedMediaItems: [DiveMediaPhoto] {
        if !cachedTaggedMediaItems.isEmpty { return cachedTaggedMediaItems }
        return DiveBuddyTaggedMediaPresentation.photosAvailableFromTagRelationships(
            effectiveBuddyMediaTags
        )
    }

    private var displayHeroTaggedMedia: DiveMediaPhoto? {
        let photos = buddyHeaderTaggedMediaItems
        guard !photos.isEmpty else { return heroTaggedMedia }
        let selectedID = heroTaggedMediaID ?? resolvedHeroMediaPhotoID(from: photos)
        return DiveActivityMediaPresentation.selectedMedia(
            selectedID: selectedID,
            in: photos
        ) ?? heroTaggedMedia
    }

    private var expectsBuddyHeroTaggedMedia: Bool {
        !effectiveBuddyMediaTags.isEmpty
    }

    private var buddyDetailContentToken: String {
        [
            buddy.id.uuidString,
            "\(effectiveBuddyDiveTags.count)",
            "\(effectiveBuddyMediaTags.count)",
            "\(ownerNumberingRows.count)",
            diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives ? "1" : "0",
        ].joined(separator: "|")
    }

    var body: some View {
        if DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: accountSession.currentProfile) {
            ProfileView()
        } else {
            buddyDetailsPage
        }
    }

    private var buddyDetailsPage: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let safeTop = max(rawSafeTop, layoutSafeAreaTopFloor)
                let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                )
                let geometryHeight = max(proxy.size.height, 1)
                let bottomScrollInset = HomeOverviewLayout.pushedPageScrollBottomInset(
                    safeAreaBottom: proxy.safeAreaInsets.bottom
                )
                let layoutHeight = HomeOverviewLayout.pushedPageLayoutHeight(
                    from: geometryHeight,
                    transitionViewportFloor: layoutViewportHeightFloor
                )
                let heroTopSafeAreaInset = HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                    rawGeometrySafeTop: proxy.safeAreaInsets.top,
                    transitionSafeTopFloor: layoutSafeAreaTopFloor
                )
                let heroHeight = DiveBuddyDetailPresentation.heroHeight(
                    viewportHeight: geometryHeight,
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: heroTopSafeAreaInset,
                    statsPanelContentHeight: homeAlignedStatsPanelContentHeight,
                    showsBuddyLeaderboard: homeLayoutSeamInputs.showsBuddyLeaderboard,
                    transitionViewportFloor: layoutViewportHeightFloor
                )

                ZStack(alignment: .top) {
                    VStack(spacing: -HomeLifetimeStatsLayout.panelOverlap) {
                        PushedHeroBand(
                            height: heroHeight,
                            topSafeAreaInset: heroTopSafeAreaInset
                        ) {
                            DiveBuddyDetailHeroHeaderView(
                                media: showsDeferredBuddyChrome ? displayHeroTaggedMedia : heroBootstrapMedia,
                                mapPins: showsDeferredBuddyChrome ? cachedMapPins : [],
                                mapFitLayout: TripDetailMapFitLayout(
                                    mapHeight: heroHeight,
                                    topObstructionHeight: topInset
                                ),
                                height: heroHeight,
                                expectsTaggedMedia: expectsBuddyHeroTaggedMedia,
                                isMapContentReady: showsDeferredBuddyChrome,
                                shouldAutoPlaySelectedVideo: showsDeferredBuddyChrome
                                    && DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(
                                        for: displayHeroTaggedMedia
                                    ),
                                onSiteSelected: openDiveSiteFromMap,
                                selectedMode: $buddyHeroMode
                            )
                        }

                        HomeLifetimeStatsPanel(
                            overlapsMedia: true,
                            bottomSafeAreaInset: 0
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                buddyIdentityRow

                                buddyContentPager(
                                    bottomScrollInset: bottomScrollInset
                                )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                        .overlay(alignment: .topLeading) {
                            buddyAvatarHeader
                                .padding(.leading, DiveBuddyDetailPresentation.avatarLeadingInset)
                                .offset(y: -Layout.avatarOverlapOffset)
                                .accessibilityIdentifier("DiveBuddyDetails.AvatarOverlay")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("DiveBuddyDetails.ContentPanel")
                        .zIndex(1)
                        .ignoresSafeArea(edges: .bottom)
                    }
                    .overlay(alignment: .top) {
                        if showsDeferredBuddyChrome, !cachedMapPins.isEmpty {
                            DiveBuddyDetailHeroModeToggle(selectedMode: $buddyHeroMode)
                                .padding(.trailing, AppTheme.Spacing.md)
                                .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                                .frame(width: proxy.size.width, height: heroHeight, alignment: .bottomTrailing)
                        }
                    }
                    .frame(width: proxy.size.width, height: layoutHeight, alignment: .top)
                    .ignoresSafeArea(edges: .bottom)
                    .animation(nil, value: heroHeight)

                    buddyDetailBackChrome(safeTop: safeTop, topInset: topInset)
                }
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    guard height > 0, height != headerClearance else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        headerClearance = height
                    }
                }
                .onChange(of: rawSafeTop, initial: true) { _, resolvedTop in
                    guard resolvedTop > layoutSafeAreaTopFloor else { return }
                    layoutSafeAreaTopFloor = resolvedTop
                }
                .onChange(of: geometryHeight, initial: true) { _, height in
                    let subtractedViewport = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: height)
                    let transitionViewport = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(
                        from: height
                    )
                    guard subtractedViewport < transitionViewport else { return }
                    guard transitionViewport > layoutViewportHeightFloor else { return }
                    layoutViewportHeightFloor = transitionViewport
                }
            }
        }
        .ignoresSafeArea(edges: [.horizontal])
        .navigationDestination(item: $buddyDiveNavigationID) { target in
            if let activity = ownerDiveActivitiesForLayout.first(where: { $0.id == target.id }) {
                ViewSingleActivity(activity: activity)
            }
        }
        .navigationDestination(item: $buddySiteNavigationID) { siteID in
            if let site = TripDetailDiveSiteNavigation.resolvedSite(
                siteID: siteID,
                plannedSites: [],
                catalogSites: cachedCatalogSites
            ) {
                ExploreDiveSiteDetailView(
                    site: site,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: openSharedDive
                )
            }
        }
        .task(id: buddy.id) {
            await Task.yield()
            showsDeferredBuddyChrome = true
        }
        .task(id: buddyDetailContentToken, priority: .utility) {
            await Task.yield()
            if ownerNumberingRows.isEmpty, let ownerProfileID {
                let ownerDiveIndex = DiveBuddyDetailPresentation.fetchOwnerDiveIndex(
                    ownerProfileID: ownerProfileID,
                    modelContext: modelContext
                )
                ownerNumberingRows = ownerDiveIndex.numberingRows
                ownerActivityTimeZoneOffsets = ownerDiveIndex.timeZoneOffsetByActivityID
            }
            rebuildBuddyDetailContent(includeSecondarySections: false, includeMarineLifeEnrichment: false)
            await Task.yield()
            rebuildBuddyDetailContent(includeSecondarySections: true, includeMarineLifeEnrichment: false)
            await Task.yield()
            rebuildBuddyDetailContent(includeSecondarySections: true, includeMarineLifeEnrichment: true)
            await warmBuddyHeroHeaderMediaPreviewIfNeeded()
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.buddyDetail(buddy.id))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.buddyDetail(buddy.id))
        }
        .sheet(isPresented: $showsEditSheet) {
            DiveBuddyEditSheetView(
                buddy: buddy,
                onSaved: {
                    showsEditSheet = false
                },
                onDeleted: {
                    showsEditSheet = false
                    dismiss()
                }
            )
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showsContactPicker) {
            ContactPickerView(
                onPick: { contact in
                    showsContactPicker = false
                    linkContact(contact)
                },
                onCancel: {
                    showsContactPicker = false
                }
            )
        }
        .task(id: buddy.id) {
            guard buddy.contactsIdentifier != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            refreshLinkedContactOnAppear()
        }
        #endif
        .alert("Contacts", isPresented: contactsAccessAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactsAccessError ?? "")
        }
        .alert("Could not link contact", isPresented: contactLinkAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactLinkError ?? "")
        }
        .accessibilityIdentifier("DiveBuddyDetails.Root")
    }

    private var heroBootstrapMedia: DiveMediaPhoto? {
        guard let media = displayHeroTaggedMedia,
              media.resolvedMediaKind != .video else { return nil }
        return media
    }

    private func catalogSitesFromSharedDives(_ sharedDives: [DiveActivity]) -> [DiveSite] {
        var byID: [UUID: DiveSite] = [:]
        for dive in sharedDives {
            if let site = dive.diveSite {
                byID[site.id] = site
            }
        }
        return Array(byID.values)
    }

    private func resolvedHeroMediaPhotoID(from photos: [DiveMediaPhoto]) -> UUID? {
        DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
            in: photos,
            explicitFeaturedID: buddy.featuredTaggedMediaPhotoID,
            sessionRandomID: DiveBuddyHeroMediaSession.resolvedRandomHeroMediaID(
                buddyID: buddy.id,
                in: photos
            )
        )
    }

    private func rebuildBuddyDetailContent(
        includeSecondarySections: Bool,
        includeMarineLifeEnrichment: Bool
    ) {
        guard let ownerProfileID else { return }

        let diveTags = effectiveBuddyDiveTags
        let mediaTags = effectiveBuddyMediaTags
        let ownerDiveActivityIDs = ownerDiveIDsForLayout

        let sharedDives = DiveBuddyRosterPresentation.sharedDiveActivities(
            from: diveTags,
            ownerProfileID: ownerProfileID
        )
        cachedSharedDiveActivities = sharedDives
        cachedSharedDiveCount = sharedDives.count

        cachedDiveRows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
            sharedDives: sharedDives,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            numberingRows: ownerNumberingRows
        )

        let taggedMedia = DiveBuddyTaggedMediaPresentation.taggedMediaPhotos(
            tags: mediaTags,
            ownerDiveActivityIDs: ownerDiveActivityIDs
        )
        cachedTaggedMediaItems = taggedMedia

        if includeSecondarySections {
            let catalogSites = catalogSitesFromSharedDives(sharedDives)
            cachedCatalogSites = catalogSites
            cachedMapPins = DiveBuddyDetailMapPresentation.pins(
                from: sharedDives,
                catalogSites: catalogSites
            )
            if cachedMapPins.isEmpty, buddyHeroMode == .map {
                buddyHeroMode = .media
            }

            cachedTripRows = DiveBuddyTripPresentation.sortedAssociatedTrips(
                DiveBuddyTripPresentation.associatedTrips(
                    buddyID: buddy.id,
                    ownerProfileID: ownerProfileID,
                    trips: DiveBuddyDetailPresentation.fetchOwnerTrips(
                        ownerProfileID: ownerProfileID,
                        modelContext: modelContext
                    ),
                    sharedDiveIDs: Set(sharedDives.map(\.id))
                )
            ).map { DiveBuddyTripPresentation.rowDisplayData(for: $0) }

            let offsetByActivityID = ownerActivityTimeZoneOffsets.isEmpty
                ? Dictionary(uniqueKeysWithValues: sharedDives.map { ($0.id, $0.timeZoneOffsetSeconds) })
                : ownerActivityTimeZoneOffsets
            cachedTaggedMediaTimeZoneOffsetByID = DiveBuddyTaggedMediaPresentation.timeZoneOffsetByMediaID(
                tags: mediaTags,
                ownerDiveActivityIDs: ownerDiveActivityIDs,
                timeZoneOffsetByActivityID: offsetByActivityID
            )
            cachedLinkedMediaItems = DiveBuddyTaggedMediaPresentation.linkedMediaItems(
                tags: mediaTags,
                ownerDiveActivityIDs: ownerDiveActivityIDs,
                mediaItems: taggedMedia
            )
        }

        if includeMarineLifeEnrichment, !taggedMedia.isEmpty {
            if cachedMarineLifeCatalog.isEmpty {
                cachedMarineLifeCatalog = (try? modelContext.fetch(
                    FetchDescriptor<MarineLife>(sortBy: [SortDescriptor(\.commonName)])
                )) ?? []
            }
            let taggedMediaIDs = Set(taggedMedia.map(\.id))
            let sightings = (try? MarineLifeSightingRecorder.sightings(
                forMediaPhotoIDs: taggedMediaIDs,
                modelContext: modelContext
            )) ?? []
            cachedTaggedMediaSightings = DiveBuddyTaggedMediaPresentation.sightingsForTaggedMedia(
                allSightings: sightings,
                taggedMediaItemIDs: taggedMediaIDs
            )
        } else if !includeMarineLifeEnrichment {
            cachedTaggedMediaSightings = []
        }

        if heroTaggedMediaID == nil {
            heroTaggedMediaID = resolvedHeroMediaPhotoID(
                from: taggedMedia.isEmpty
                    ? DiveBuddyTaggedMediaPresentation.photosAvailableFromTagRelationships(mediaTags)
                    : taggedMedia
            )
        }

        gallerySelectedMediaID = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: gallerySelectedMediaID,
            in: taggedMedia
        )

        if let heroID = heroTaggedMediaID,
           let hero = buddyHeaderTaggedMediaItems.first(where: { $0.id == heroID }) {
            DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: hero)
        }
    }

    private func warmBuddyHeroHeaderMediaPreviewIfNeeded() async {
        guard let heroID = heroTaggedMediaID ?? resolvedHeroMediaPhotoID(from: buddyHeaderTaggedMediaItems),
              let hero = buddyHeaderTaggedMediaItems.first(where: { $0.id == heroID })
        else { return }
        await DiveMediaPreviewStorage.ensureStoredPreviews(for: [hero], modelContext: modelContext)
    }

    @ViewBuilder
    private func buddyDetailBackChrome(
        safeTop: CGFloat,
        topInset: CGFloat
    ) -> some View {
        LogbookTopChromeScrim(topObstructionHeight: topInset)
            .padding(.top, -safeTop)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .zIndex(0.5)

        Color.clear
            .frame(height: topInset)
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .zIndex(0.75)

        AppHeader(
            title: "",
            showsBackButton: true,
            showsBrandWordmark: false,
            statusBarSafeAreaTop: safeTop
        ) {
            Button("Edit") {
                showsEditSheet = true
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabSelected)
            .accessibilityIdentifier("DiveBuddyDetails.Edit")
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .zIndex(1)
    }

    private func openSharedDive(_ diveID: UUID) {
        buddyDiveNavigationID = BuddyDiveNavigationID(id: diveID)
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        if let openCatalogDiveSiteDetail {
            openCatalogDiveSiteDetail(siteID)
        } else {
            buddySiteNavigationID = siteID
        }
    }

    private func toggleFeaturedTaggedMedia() {
        guard let selectedID = gallerySelectedMediaID,
              let selectedMedia = cachedTaggedMediaItems.first(where: { $0.id == selectedID })
        else { return }

        let nextFeaturedID = DiveBuddyTaggedMediaPresentation.toggledFeaturedMediaPhotoID(
            mediaID: selectedMedia.id,
            explicitFeaturedID: buddy.featuredTaggedMediaPhotoID
        )
        try? DiveBuddyFeaturedMediaStorage.setFeaturedTaggedMedia(
            nextFeaturedID,
            on: buddy,
            modelContext: modelContext
        )

        if let nextFeaturedID {
            heroTaggedMediaID = nextFeaturedID
        } else {
            heroTaggedMediaID = DiveBuddyHeroMediaSession.pickNewRandomHeroMediaID(
                buddyID: buddy.id,
                in: cachedTaggedMediaItems
            )
        }
    }

    private var contactsAccessAlertBinding: Binding<Bool> {
        Binding(
            get: { contactsAccessError != nil },
            set: { if !$0 { contactsAccessError = nil } }
        )
    }

    private var contactLinkAlertBinding: Binding<Bool> {
        Binding(
            get: { contactLinkError != nil },
            set: { if !$0 { contactLinkError = nil } }
        )
    }

    private enum Layout {
        static let avatarDiameter = DiveBuddyDetailPresentation.profileAvatarDiameter
        static let contactBadgeDiameter = DiveBuddyDetailPresentation.contactBadgeDiameter
        static let avatarOverlapOffset = DiveBuddyDetailPresentation.avatarOverlapOffset()
    }

    private var buddyIdentityRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Color.clear
                .frame(
                    width: Layout.avatarDiameter,
                    height: Layout.avatarOverlapOffset
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(buddy.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(DiveBuddyRosterPresentation.sharedDiveCountLabel(headerSharedDiveCount))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            .offset(y: -DiveBuddyDetailPresentation.identityTextLift)

            Spacer(minLength: 0)
        }
        .padding(.bottom, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveBuddyDetails.Header")
    }

    @ViewBuilder
    private func buddyContentPager(
        bottomScrollInset: CGFloat
    ) -> some View {
        if showsDeferredBuddyChrome {
            DiveBuddyDetailContentPager(
                diveRows: cachedDiveRows,
                tripRows: cachedTripRows,
                taggedMediaItems: cachedTaggedMediaItems,
                taggedMediaTimeZoneOffsetByID: cachedTaggedMediaTimeZoneOffsetByID,
                linkedMediaItems: cachedLinkedMediaItems,
                mediaSightings: cachedTaggedMediaSightings,
                marineLifeCatalog: cachedMarineLifeCatalog,
                ownerProfileID: ownerProfileID,
                featuredTaggedMediaPhotoID: buddy.featuredTaggedMediaPhotoID,
                gallerySelectedMediaID: $gallerySelectedMediaID,
                bottomScrollInset: bottomScrollInset,
                onToggleFeaturedTaggedMedia: toggleFeaturedTaggedMedia,
                onOpenDive: openSharedDive
            )
        } else if !cachedDiveRows.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    LinkedDiveLogbookListRows(
                        rows: cachedDiveRows,
                        listAccessibilityIdentifier: "DiveBuddyDetails.DiveList",
                        onOpenDive: openSharedDive
                    )
                    .accessibilityIdentifier("DiveBuddyDetails.DivesTogether")

                    Color.clear
                        .frame(height: bottomScrollInset)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollClipDisabled(false)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .bottom)
            .homeSheetPanelBottomScrollFade()
            .accessibilityIdentifier("DiveBuddyDetails.ContentPager.Bootstrap")
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("DiveBuddyDetails.ContentPager.Bootstrap")
        }
    }

    @ViewBuilder
    private var buddyAvatarHeader: some View {
        #if canImport(UIKit)
        ZStack(alignment: .bottomTrailing) {
            ProfileAvatarView(
                profilePhoto: buddy.profilePhoto,
                diameter: Layout.avatarDiameter,
                iconFont: .system(size: 56),
                placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
            )

            contactLinkBadge
        }
        #else
        ProfileAvatarView(
            profilePhoto: buddy.profilePhoto,
            diameter: Layout.avatarDiameter,
            iconFont: .system(size: 56),
            placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
        )
        #endif
    }

    #if canImport(UIKit)
    private var contactLinkBadge: some View {
        Button {
            presentContactPicker()
        } label: {
            Image(
                systemName: buddy.contactsIdentifier != nil
                    ? "person.fill"
                    : "person.badge.plus"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: Layout.contactBadgeDiameter, height: Layout.contactBadgeDiameter)
            .background(Circle().fill(AppTheme.Colors.tabSelected))
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            buddy.contactsIdentifier != nil ? "Change linked contact" : "Link contact"
        )
        .accessibilityIdentifier("DiveBuddyDetails.ContactLink")
    }
    #endif

    #if canImport(UIKit)
    private func presentContactPicker() {
        ContactsPickerAccess.presentIfAuthorized(
            onAuthorized: { showsContactPicker = true },
            onError: { contactsAccessError = $0 }
        )
    }

    private func linkContact(_ contact: CNContact) {
        do {
            try DiveBuddyContactLinking.apply(
                contact: contact,
                to: buddy,
                owner: accountSession.currentProfile,
                modelContext: modelContext
            )
            try modelContext.save()
            DiveBuddyRosterChangeNotification.post()
        } catch {
            contactLinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Silent refresh when opening a buddy already linked to Contacts.
    private func refreshLinkedContactOnAppear() {
        guard buddy.contactsIdentifier != nil else { return }
        do {
            let priorDisplayName = buddy.displayName
            let priorPhotoKey = ProfileAvatarImageCachePresentation.cacheKey(for: buddy.profilePhoto ?? Data())
            try DiveBuddyContactLinking.refreshFromContacts(buddy)
            try modelContext.save()
            let nextPhotoKey = ProfileAvatarImageCachePresentation.cacheKey(for: buddy.profilePhoto ?? Data())
            if priorPhotoKey != nextPhotoKey || priorDisplayName != buddy.displayName {
                DiveBuddyRosterChangeNotification.post()
            }
        } catch {
            // Best-effort on load — user can still change contact via the picker.
        }
    }
    #endif
}
