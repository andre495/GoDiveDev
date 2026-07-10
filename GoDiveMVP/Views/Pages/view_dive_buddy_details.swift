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
    @State private var showsDeferredHeroMap = false
    @State private var allowsHeroVideoAutoplay = false
    @State private var hasLoadedMarineLifeEnrichment = false
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
    @State private var hasLoadedTripRows = false

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
        _cachedMapPins = State(
            initialValue: DiveBuddyDetailPresentation.initialMapPins(
                from: initialSharedDiveContent.sharedDives
            )
        )
        _cachedCatalogSites = State(
            initialValue: DiveBuddyDetailPresentation.catalogSitesFromSharedDives(
                initialSharedDiveContent.sharedDives
            )
        )

        if let ownerProfileID = buddy.ownerProfileID,
           let index = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerProfileID) {
            _ownerNumberingRows = State(initialValue: index.numberingRows)
            _ownerActivityTimeZoneOffsets = State(initialValue: index.timeZoneOffsetByActivityID)
            let numberedRows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
                sharedDives: initialSharedDiveContent.sharedDives,
                unitSystem: AppUserSettings.diveDisplayUnitSystem(),
                useChronologicalNumbers: AppUserSettings.automaticallyRenumberDives,
                numberingRows: index.numberingRows
            )
            if !numberedRows.isEmpty {
                _cachedDiveRows = State(initialValue: numberedRows)
            }
        }
    }

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id
    }

    private var ownerDiveActivitiesForLayout: [DiveActivity] {
        cachedSharedDiveActivities
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

    private var showsBuddyHeroModeToggle: Bool {
        ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
            hasTaggedMedia: !buddyHeaderTaggedMediaItems.isEmpty,
            hasMapPin: !cachedMapPins.isEmpty
        )
    }

    private var buddyDetailContentToken: String {
        [
            buddy.id.uuidString,
            "\(ownerNumberingRows.count)",
            diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives ? "1" : "0",
        ].joined(separator: "|")
    }

    var body: some View {
        if DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: accountSession.currentProfile) {
            ProfileView(ownerProfileID: ownerProfileID)
        } else {
            buddyDetailsPage
        }
    }

    private var buddyDetailsPage: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "DiveBuddyDetails.Root"
            ),
            hero: { context in
                DiveBuddyDetailHeroHeaderView(
                    media: displayHeroTaggedMedia,
                    mapPins: showsDeferredHeroMap ? cachedMapPins : [],
                    mapFitLayout: context.mapFitLayout(),
                    height: context.heroHeight,
                    expectsTaggedMedia: expectsBuddyHeroTaggedMedia,
                    isMapContentReady: showsDeferredHeroMap,
                    shouldAutoPlaySelectedVideo: allowsHeroVideoAutoplay
                        && DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(
                            for: displayHeroTaggedMedia
                        ),
                    onSiteSelected: openDiveSiteFromMap,
                    selectedMode: $buddyHeroMode
                )
            },
            heroOverlay: { _ in
                if showsBuddyHeroModeToggle {
                    DiveBuddyDetailHeroModeToggle(selectedMode: $buddyHeroMode)
                        .padding(.trailing, AppTheme.Spacing.md)
                        .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                }
            },
            panelOverlay: {
                buddyAvatarHeader
                    .padding(.leading, DiveBuddyDetailPresentation.avatarLeadingInset)
                    .offset(y: -Layout.avatarOverlapOffset)
                    .accessibilityIdentifier("DiveBuddyDetails.AvatarOverlay")
            },
            pinnedContent: {
                buddyPinnedSummary
            },
            panelContent: { bottomScrollInset, _ in
                buddyContentPager(
                    bottomScrollInset: bottomScrollInset,
                    onPageFirstMounted: handleBuddyPagerPageFirstMounted
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    onEdit: { showsEditSheet = true },
                    editAccessibilityIdentifier: "DiveBuddyDetails.Edit"
                )
            }
        )
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
        .task(id: buddyDetailContentToken, priority: .userInitiated) {
            await Task.yield()

            try? await Task.sleep(for: PushedNavigationDeferralPresentation.afterPushMapDeferral)
            guard !Task.isCancelled else { return }
            showsDeferredHeroMap = true

            async let contentRefresh: Void = refreshBuddyDetailContentAfterDeferral()
            async let numberingRefresh: Void = refreshOwnerDiveNumberingIfNeeded()
            async let heroWarm: Void = warmBuddyHeroHeaderMediaPreviewIfNeeded()
            _ = await (contentRefresh, numberingRefresh, heroWarm)

            if !Task.isCancelled {
                allowsHeroVideoAutoplay = true
            }
        }
        .onAppear {
            prepareBuddyChromeForDisplay()
            DiveMediaScopeCache.shared.activateScope(.buddyDetail(buddy.id))
        }
        .onChange(of: buddyDiveTags.count) { _, _ in
            refreshBuddyDetailContentAfterTagChange()
        }
        .onChange(of: buddyMediaTags.count) { _, _ in
            refreshBuddyDetailContentAfterTagChange()
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
    }

    private func catalogSitesFromSharedDives(_ sharedDives: [DiveActivity]) -> [DiveSite] {
        DiveBuddyDetailPresentation.catalogSitesFromSharedDives(sharedDives)
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
        includeTripRows: Bool = false,
        includeMarineLifeEnrichment: Bool
    ) {
        let signpostID = AppPerformanceSignpost.begin(.buddyDetailContentRebuild)
        defer { AppPerformanceSignpost.end(.buddyDetailContentRebuild, signpostID: signpostID) }

        guard let ownerProfileID else { return }

        let diveTags = effectiveBuddyDiveTags
        let mediaTags = effectiveBuddyMediaTags

        let sharedDives = DiveBuddyRosterPresentation.sharedDiveActivities(
            from: diveTags,
            ownerProfileID: ownerProfileID
        )
        cachedSharedDiveActivities = sharedDives
        cachedSharedDiveCount = sharedDives.count
        let ownerDiveActivityIDs = DiveBuddyDetailPresentation.mediaScopeDiveActivityIDs(
            sharedDiveActivities: sharedDives,
            mediaTags: mediaTags
        )

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

            if includeTripRows {
                // Populated asynchronously via **`loadBuddyTripRowsIfNeeded`**.
            }

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

        if includeMarineLifeEnrichment {
            hasLoadedMarineLifeEnrichment = true
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
    }

    private func refreshBuddyDetailContentAfterDeferral() async {
        await Task.yield()
        guard !Task.isCancelled else { return }
        rebuildBuddyDetailContent(
            includeSecondarySections: true,
            includeTripRows: false,
            includeMarineLifeEnrichment: false
        )
    }

    private func loadBuddyMarineLifeCatalogIfNeeded() async {
        guard cachedMarineLifeCatalog.isEmpty else { return }
        cachedMarineLifeCatalog = await MarineLifeCatalogLoader.loadSortedCatalog(modelContext: modelContext)
    }

    private func loadBuddyTripRowsIfNeeded(force: Bool = false) async {
        guard let ownerProfileID else { return }
        if !force, !cachedTripRows.isEmpty { return }
        let ownerTrips = await DiveBuddyDetailPresentation.fetchOwnerTripsAsync(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        )
        guard !Task.isCancelled else { return }
        cachedTripRows = DiveBuddyTripPresentation.sortedAssociatedTrips(
            DiveBuddyTripPresentation.associatedTrips(
                buddyID: buddy.id,
                ownerProfileID: ownerProfileID,
                trips: ownerTrips,
                sharedDiveIDs: Set(cachedSharedDiveActivities.map(\.id))
            )
        ).map { DiveBuddyTripPresentation.rowDisplayData(for: $0) }
    }

    private func prepareBuddyChromeForDisplay() {
        DiveMediaPreviewStorage.seedSessionCache(for: cachedTaggedMediaItems)
        syncHeroTaggedMediaSelection()
        if let hero = displayHeroTaggedMedia,
           DiveMediaPreviewStorage.hasStoredPreview(for: hero) {
            allowsHeroVideoAutoplay = DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: hero)
        }
    }

    private func refreshBuddyDetailContentAfterTagChange() {
        rebuildBuddyDetailContent(
            includeSecondarySections: true,
            includeTripRows: hasLoadedTripRows,
            includeMarineLifeEnrichment: hasLoadedMarineLifeEnrichment
        )
        if hasLoadedTripRows {
            Task { await loadBuddyTripRowsIfNeeded(force: true) }
        }
    }

    private func warmBuddyHeroHeaderMediaPreviewIfNeeded() async {
        guard let heroID = heroTaggedMediaID ?? resolvedHeroMediaPhotoID(from: buddyHeaderTaggedMediaItems),
              let hero = buddyHeaderTaggedMediaItems.first(where: { $0.id == heroID })
        else { return }
        DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: hero)
        await DiveMediaPreviewStorage.ensureStoredPreviews(for: [hero], modelContext: modelContext)
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

    private var buddyPinnedSummary: some View {
        BlueSheetPinnedSummary(
            accent: DiveBuddyRosterPresentation.sharedDiveCountLabel(headerSharedDiveCount),
            accentFont: BlueSheetPinnedSummaryPresentation.buddyAccentFont,
            title: buddy.displayName,
            titleFont: BlueSheetPinnedSummaryPresentation.buddyTitleFont,
            titleLineLimit: 2,
            titleMinimumScaleFactor: 0.85,
            accessibilityIdentifier: "DiveBuddyDetails.Header",
            usesLeadingAccessoryLayout: true,
            contentVerticalOffset: -DiveBuddyDetailPresentation.identityTextLift,
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

    @ViewBuilder
    private func buddyContentPager(
        bottomScrollInset: CGFloat,
        onPageFirstMounted: @escaping (DiveBuddyDetailContentPage) -> Void
    ) -> some View {
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
            onOpenDive: openSharedDive,
            onPageFirstMounted: onPageFirstMounted
        )
    }

    private func handleBuddyPagerPageFirstMounted(_ page: DiveBuddyDetailContentPage) {
        switch page {
        case .tripsTogether:
            guard !hasLoadedTripRows else { return }
            hasLoadedTripRows = true
            Task {
                await loadBuddyTripRowsIfNeeded()
            }
        case .taggedMedia:
            guard !hasLoadedMarineLifeEnrichment else { return }
            hasLoadedMarineLifeEnrichment = true
            rebuildBuddyDetailContent(
                includeSecondarySections: true,
                includeTripRows: hasLoadedTripRows,
                includeMarineLifeEnrichment: true
            )
            Task {
                await loadBuddyMarineLifeCatalogIfNeeded()
            }
        case .divesTogether:
            break
        }
    }

    private func applyOwnerDiveIndex(_ index: DiveBuddyDetailPresentation.OwnerDiveIndex) {
        ownerNumberingRows = index.numberingRows
        ownerActivityTimeZoneOffsets = index.timeZoneOffsetByActivityID
    }

    private func applyOwnerDiveIndexIfNeeded() async {
        guard ownerNumberingRows.isEmpty, let ownerProfileID else { return }

        if let cached = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerProfileID) {
            applyOwnerDiveIndex(cached)
            return
        }

        await Task.yield()
        guard !Task.isCancelled else { return }

        if let cached = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerProfileID) {
            applyOwnerDiveIndex(cached)
            return
        }

        let index = await DiveBuddyDetailPresentation.fetchOwnerDiveIndex(
            ownerProfileID: ownerProfileID,
            container: modelContext.container
        )
        OwnerDiveIndexSessionCache.publish(index, ownerProfileID: ownerProfileID)
        applyOwnerDiveIndex(index)
    }

    private func syncHeroTaggedMediaSelection() {
        let photos = buddyHeaderTaggedMediaItems
        guard !photos.isEmpty else {
            heroTaggedMediaID = nil
            return
        }
        if let heroTaggedMediaID,
           photos.contains(where: { $0.id == heroTaggedMediaID }) {
            return
        }
        heroTaggedMediaID = resolvedHeroMediaPhotoID(from: photos)
    }

    private func refreshOwnerDiveNumberingIfNeeded() async {
        guard ownerNumberingRows.isEmpty else { return }
        await applyOwnerDiveIndexIfNeeded()
        guard !Task.isCancelled else { return }
        rebuildBuddyDetailContent(
            includeSecondarySections: showsDeferredHeroMap,
            includeTripRows: hasLoadedTripRows,
            includeMarineLifeEnrichment: hasLoadedMarineLifeEnrichment
        )
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
