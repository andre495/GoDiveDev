import SwiftData
import SwiftUI

/// Pushed catalog dive-site detail from **Explore** (blue sheet + media/map hero).
struct ExploreDiveSiteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @Bindable var site: DiveSite
    let ownerProfileID: UUID?
    let onOpenDive: (UUID) -> Void

    @State private var contentSnapshot = ExploreDiveSiteDetailContentSnapshot.empty
    @State private var siteHeroMode: PushedDetailHeroHeaderView.Mode
    @State private var heroTaggedMediaID: UUID?
    @State private var showsDeferredHeroMap = false
    @State private var hasLoadedMarineLifeEnrichment = false

    init(
        site: DiveSite,
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void = { _ in }
    ) {
        self.site = site
        self.ownerProfileID = ownerProfileID
        self.onOpenDive = onOpenDive

        let relationshipActivities = ExploreDiveSiteDetailContentSnapshotBuilder.siteActivitiesFromRelationships(
            site: site,
            ownerProfileID: ownerProfileID
        )
        let initialSnapshot = ExploreDiveSiteDetailContentSnapshotBuilder.buildLight(
            site: site,
            siteActivities: relationshipActivities,
            ownerProfileID: ownerProfileID,
            unitSystem: AppUserSettings.diveDisplayUnitSystem()
        )
        _contentSnapshot = State(initialValue: initialSnapshot)
        _heroTaggedMediaID = State(
            initialValue: ExploreDiveSiteDetailPresentation.initialHeroTaggedMediaPhotoID(
                from: initialSnapshot.taggedMediaItems
            )
        )

        let mapPins = ExploreDiveSiteDetailPresentation.mapPins(for: site)
        _siteHeroMode = State(
            initialValue: mapPins.isEmpty ? .media : .map
        )
    }

    private var displayRecord: DiveSiteDisplayRecord {
        DiveSitePresentation.listRecord(for: site)
    }

    private var mapPins: [TripDetailMapPin] {
        ExploreDiveSiteDetailPresentation.mapPins(for: site)
    }

    private var showsHeroModeToggle: Bool {
        ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
            hasTaggedMedia: !contentSnapshot.taggedMediaItems.isEmpty,
            hasMapPin: !mapPins.isEmpty
        )
    }

    private var expectsHeroTaggedMedia: Bool {
        if !contentSnapshot.taggedMediaItems.isEmpty { return true }
        guard accountSession.currentProfile != nil else { return false }
        return ExploreDiveSiteMediaPresentation.expectsHeroMedia(
            siteActivities: contentSnapshot.siteDiveActivities
        )
    }

    private var heroTaggedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: heroTaggedMediaID,
            in: contentSnapshot.taggedMediaItems
        )
    }

    private var ownerHasVisitedSite: Bool {
        accountSession.currentProfile != nil && !contentSnapshot.siteDiveActivities.isEmpty
    }

    private var isStarRatingEditable: Bool {
        DiveSitePresentation.isStarRatingEditable(
            ownerHasVisited: ownerHasVisitedSite,
            isReferenceOnly: false
        )
    }

    private var displayStarRating: Int {
        DiveSitePresentation.displayPinnedStarRating(from: site.siteRating)
    }

    private var siteDetailContentToken: String {
        [
            site.id.uuidString,
            accountSession.currentProfile?.id.uuidString ?? "nil",
            diveDisplayUnitSystem.rawValue,
            ExploreDiveSiteMediaPresentation.galleryRefreshToken(
                diveSiteID: site.id,
                ownerProfileID: accountSession.currentProfile?.id,
                activities: contentSnapshot.siteDiveActivities
            ),
        ].joined(separator: "|")
    }

    var body: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "Explore.DiveSiteDetail.Root"
            ),
            hero: { context in
                PushedDetailHeroHeaderView(
                    media: heroTaggedMedia,
                    mapPins: showsDeferredHeroMap ? mapPins : [],
                    mapFitLayout: context.mapFitLayout(),
                    height: context.heroHeight,
                    expectsTaggedMedia: expectsHeroTaggedMedia,
                    isMapContentReady: showsDeferredHeroMap,
                    shouldAutoPlaySelectedVideo: DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(
                        for: heroTaggedMedia
                    ),
                    style: .diveSite,
                    onSiteSelected: { _ in },
                    selectedMode: $siteHeroMode
                )
            },
            heroOverlay: { _ in
                if showsHeroModeToggle {
                    PushedDetailHeroModeToggle(
                        selectedMode: $siteHeroMode,
                        accessibilityIdentifierPrefix: "Explore.DiveSiteDetail.Hero.ModeToggle"
                    )
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                }
            },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                ExploreDiveSiteDetailPinnedTitleView(
                    record: displayRecord,
                    starRating: displayStarRating,
                    isStarRatingEditable: isStarRatingEditable,
                    onStarRatingSelected: updateSiteRating,
                    accessibilityIdentifier: "Explore.DiveSiteDetail.TitleBlock"
                )
            },
            panelContent: { bottomScrollInset, _ in
                ExploreDiveSiteDetailContentPager(
                    displayRecord: displayRecord,
                    siteDiveRows: contentSnapshot.siteDiveRows,
                    sightedSpeciesLinks: contentSnapshot.sightedSpeciesLinks,
                    taggedMediaItems: contentSnapshot.taggedMediaItems,
                    taggedMediaTimeZoneOffsetByID: contentSnapshot.taggedMediaTimeZoneOffsetByID,
                    linkedMediaItems: contentSnapshot.linkedMediaItems,
                    mediaSightings: contentSnapshot.siteSightings,
                    marineLifeCatalog: contentSnapshot.marineLifeCatalog,
                    ownerProfileID: accountSession.currentProfile?.id,
                    gallerySelectedMediaID: $heroTaggedMediaID,
                    bottomScrollInset: bottomScrollInset,
                    onOpenDive: onOpenDive,
                    onPageFirstMounted: handleSitePagerPageFirstMounted
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    isEditEnabled: isStarRatingEditable,
                    onEdit: {},
                    editAccessibilityIdentifier: "ExploreDiveSiteDetail.Edit"
                )
            }
        )
        .task(id: siteDetailContentToken, priority: .userInitiated) {
            await Task.yield()

            try? await Task.sleep(for: PushedNavigationDeferralPresentation.afterPushMapDeferral)
            guard !Task.isCancelled else { return }
            showsDeferredHeroMap = true
            syncHeroPresentation()

            rebuildSiteDetailContent(includeMarineLifeEnrichment: hasLoadedMarineLifeEnrichment)
        }
        .onAppear {
            DiveMediaPreviewStorage.seedSessionCache(for: contentSnapshot.taggedMediaItems)
            DiveMediaScopeCache.shared.activateScope(.diveSite(site.id))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.diveSite(site.id))
        }
        .onChange(of: mapPins.count) { _, count in
            if count == 0, siteHeroMode == .map {
                siteHeroMode = .media
            }
        }
    }

    private func rebuildSiteDetailContent(includeMarineLifeEnrichment: Bool) {
        let siteActivities: [DiveActivity]
        if let ownerProfileID {
            siteActivities = ExploreDiveSiteDetailContentSnapshotBuilder.fetchSiteDiveActivities(
                diveSiteID: site.id,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext
            )
        } else {
            siteActivities = []
        }

        var snapshot = ExploreDiveSiteDetailContentSnapshotBuilder.buildLight(
            site: site,
            siteActivities: siteActivities,
            ownerProfileID: ownerProfileID ?? accountSession.currentProfile?.id,
            unitSystem: diveDisplayUnitSystem
        )

        if includeMarineLifeEnrichment {
            snapshot = ExploreDiveSiteDetailContentSnapshotBuilder.enrichMarineLife(
                snapshot: snapshot,
                site: site,
                ownerProfileID: ownerProfileID ?? accountSession.currentProfile?.id,
                modelContext: modelContext
            )
            hasLoadedMarineLifeEnrichment = true
        }

        contentSnapshot = snapshot
        syncHeroPresentation()
    }

    private func handleSitePagerPageFirstMounted(_ page: ExploreDiveSiteDetailContentPage) {
        guard !hasLoadedMarineLifeEnrichment else { return }
        switch page {
        case .marineLifeHere, .taggedMedia:
            hasLoadedMarineLifeEnrichment = true
            rebuildSiteDetailContent(includeMarineLifeEnrichment: true)
        case .diveDetails, .divesHere:
            break
        }
    }

    private func updateSiteRating(_ rating: Int) {
        guard isStarRatingEditable else { return }
        site.siteRating = DiveSitePresentation.storageSiteRating(for: rating)
        try? modelContext.save()
    }

    private func syncHeroPresentation() {
        syncHeroTaggedMediaSelection()

        let hasMedia = !contentSnapshot.taggedMediaItems.isEmpty
        let hasMap = !mapPins.isEmpty

        if hasMedia {
            siteHeroMode = .media
        } else if hasMap {
            siteHeroMode = .map
        }

        enforceSingleModeHeroWhenToggleHidden()

        if !hasMap, siteHeroMode == .map {
            siteHeroMode = .media
        }
    }

    private func enforceSingleModeHeroWhenToggleHidden() {
        let hasMedia = !contentSnapshot.taggedMediaItems.isEmpty
        let hasMap = !mapPins.isEmpty
        guard !ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
            hasTaggedMedia: hasMedia,
            hasMapPin: hasMap
        ) else { return }

        if hasMedia {
            siteHeroMode = .media
        } else if hasMap {
            siteHeroMode = .map
        }
    }

    private func syncHeroTaggedMediaSelection() {
        guard !contentSnapshot.taggedMediaItems.isEmpty else {
            heroTaggedMediaID = nil
            return
        }
        if let heroTaggedMediaID,
           contentSnapshot.taggedMediaItems.contains(where: { $0.id == heroTaggedMediaID }) {
            return
        }
        heroTaggedMediaID = ExploreDiveSiteDetailPresentation.initialHeroTaggedMediaPhotoID(
            from: contentSnapshot.taggedMediaItems
        )
    }
}

/// Explore stack routes (shared with **`ExploreView`**).
enum ExploreRoute: Hashable {
    case tripPlanner
    case tripDetail(UUID)
    case tripDetailMedia(tripID: UUID, mediaID: UUID)
    case siteDetail(UUID)
    case referenceSiteDetail(String)
    case speciesDetail(String)
    case diveDetail(UUID)
}
