import SwiftData
import SwiftUI

/// Pushed catalog dive-site detail from **Explore** (blue sheet + media/map hero).
struct ExploreDiveSiteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @Query(sort: \MarineLife.commonName) private var marineLifeCatalog: [MarineLife]
    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var siteSightings: [SightingInstance]

    @Bindable var site: DiveSite
    let onOpenDive: (UUID) -> Void

    @State private var siteHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var heroTaggedMediaID: UUID?
    @State private var ownerDiveQueryReady = false
    @State private var lastResolvedHadTaggedMedia = false
    @State private var hasCompletedInitialHeroSync = false

    init(
        site: DiveSite,
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void = { _ in }
    ) {
        self.site = site
        self.onOpenDive = onOpenDive
        let diveSiteID = site.id
        let ownerFilterID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerFilterID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _siteSightings = Query(
            filter: #Predicate<SightingInstance> { $0.diveSiteID == diveSiteID },
            sort: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
    }

    private var catalogByUUID: [String: MarineLifeCatalogSnapshot] {
        Dictionary(uniqueKeysWithValues: marineLifeCatalog.map {
            ($0.uuid, $0.fieldGuideCatalogSnapshot)
        })
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var siteDiveActivities: [DiveActivity] {
        ExploreDiveSiteMediaPresentation.siteDiveActivities(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            activities: ownerDiveActivities
        )
    }

    private var siteLinkedMediaItems: [TripDetailLinkedMediaItem] {
        ExploreDiveSiteMediaPresentation.linkedMediaItems(from: siteDiveActivities)
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        ExploreDiveSiteMediaPresentation.mediaPhotos(
            siteActivities: siteDiveActivities,
            linkedItems: siteLinkedMediaItems
        )
    }

    private var taggedMediaTimeZoneOffsetByID: [UUID: Int?] {
        ExploreDiveSiteMediaPresentation.timeZoneOffsetByMediaID(
            siteActivities: siteDiveActivities,
            linkedItems: siteLinkedMediaItems
        )
    }

    private var sightedSpeciesLinks: [DiveSiteMarineLifePresentation.SightedSpeciesLinkData] {
        DiveSiteMarineLifePresentation.sightedSpeciesLinks(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            sightings: siteSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            catalogByUUID: catalogByUUID
        )
    }

    private var siteActivityLinks: [FieldGuidePresentation.SightedActivityLinkData] {
        let snapshots = ownerDiveActivities.map {
            DiveActivitySightingLinkSnapshot(
                id: $0.id,
                diveSiteID: $0.diveSiteID,
                resolvedSiteName: $0.resolvedSiteName,
                startTime: $0.startTime,
                timeZoneOffsetSeconds: $0.timeZoneOffsetSeconds
            )
        }
        return DiveSiteMarineLifePresentation.siteActivityLinks(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            activities: snapshots
        )
    }

    private var siteDiveRows: [DiveLogbookRowDisplayData] {
        FieldGuidePresentation.sightedDiveRowDisplayData(
            activityIDs: siteActivityLinks.map(\.id),
            activities: ownerDiveActivities,
            unitSystem: diveDisplayUnitSystem
        )
    }

    private var ownerHasVisitedSite: Bool {
        accountSession.currentProfile != nil && !siteDiveActivities.isEmpty
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

    private var displayRecord: DiveSiteDisplayRecord {
        DiveSitePresentation.listRecord(for: site)
    }

    private var mapPins: [TripDetailMapPin] {
        ExploreDiveSiteDetailPresentation.mapPins(for: site)
    }

    private var showsHeroModeToggle: Bool {
        ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
            hasTaggedMedia: !taggedMediaItems.isEmpty,
            hasMapPin: !mapPins.isEmpty
        )
    }

    private var expectsHeroTaggedMedia: Bool {
        if !taggedMediaItems.isEmpty { return true }
        guard accountSession.currentProfile != nil else { return false }
        return ExploreDiveSiteMediaPresentation.expectsHeroMedia(siteActivities: siteDiveActivities)
    }

    private var heroTaggedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: heroTaggedMediaID,
            in: taggedMediaItems
        )
    }

    private var linkedMediaItems: [TripDetailLinkedMediaItem] {
        siteLinkedMediaItems
    }

    private var taggedMediaRefreshToken: String {
        ExploreDiveSiteMediaPresentation.galleryRefreshToken(
            diveSiteID: site.id,
            ownerProfileID: accountSession.currentProfile?.id,
            activities: ownerDiveActivities
        )
    }

    var body: some View {
        FieldGuideBlueSheetPage(
            accessibilityRootIdentifier: "Explore.DiveSiteDetail.Root",
            scrollAccessibilityIdentifier: "Explore.DiveSiteDetail.Scroll",
            hero: { context in
                PushedDetailHeroHeaderView(
                    media: heroTaggedMedia,
                    mapPins: mapPins,
                    mapFitLayout: context.mapFitLayout(),
                    height: context.heroHeight,
                    expectsTaggedMedia: expectsHeroTaggedMedia,
                    isMapContentReady: true,
                    shouldAutoPlaySelectedVideo: DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(
                        for: heroTaggedMedia
                    ),
                    style: .diveSite,
                    onSiteSelected: { _ in },
                    selectedMode: $siteHeroMode
                )
            },
            pinnedContent: {
                ExploreDiveSiteDetailPinnedTitleView(
                    record: displayRecord,
                    starRating: displayStarRating,
                    isStarRatingEditable: isStarRatingEditable,
                    onStarRatingSelected: updateSiteRating,
                    accessibilityIdentifier: "Explore.DiveSiteDetail.TitleBlock"
                )
            },
            panelContent: { bottomScrollInset in
                ExploreDiveSiteDetailContentPager(
                    displayRecord: displayRecord,
                    siteDiveRows: siteDiveRows,
                    sightedSpeciesLinks: sightedSpeciesLinks,
                    taggedMediaItems: taggedMediaItems,
                    taggedMediaTimeZoneOffsetByID: taggedMediaTimeZoneOffsetByID,
                    linkedMediaItems: linkedMediaItems,
                    mediaSightings: siteSightings,
                    marineLifeCatalog: marineLifeCatalog,
                    ownerProfileID: accountSession.currentProfile?.id,
                    gallerySelectedMediaID: $heroTaggedMediaID,
                    bottomScrollInset: bottomScrollInset,
                    onOpenDive: onOpenDive
                )
                .padding(.horizontal, AppTheme.Spacing.md)
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
            }
        )
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.diveSite(site.id))
            if accountSession.currentProfile == nil {
                ownerDiveQueryReady = true
            }
            syncHeroPresentation()
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.diveSite(site.id))
        }
        .onChange(of: ownerDiveActivities.count, initial: true) { _, _ in
            ownerDiveQueryReady = true
            syncHeroPresentation()
        }
        .onChange(of: taggedMediaRefreshToken) { _, _ in
            syncHeroPresentation()
        }
        .onChange(of: mapPins.count) { _, count in
            if count == 0, siteHeroMode == .map {
                siteHeroMode = .media
            }
        }
    }

    private func updateSiteRating(_ rating: Int) {
        guard isStarRatingEditable else { return }
        site.siteRating = DiveSitePresentation.storageSiteRating(for: rating)
        try? modelContext.save()
    }

    private func syncHeroPresentation() {
        syncHeroTaggedMediaSelection()

        let hasMedia = !taggedMediaItems.isEmpty
        let hasMap = !mapPins.isEmpty
        let canDefault = ExploreDiveSiteDetailPresentation.canDefaultHeroMode(
            hasOwnerProfile: accountSession.currentProfile != nil,
            ownerDiveQueryReady: ownerDiveQueryReady
        )

        if hasMedia && !lastResolvedHadTaggedMedia {
            siteHeroMode = .media
            hasCompletedInitialHeroSync = true
        } else if canDefault, !hasCompletedInitialHeroSync {
            if hasMedia {
                siteHeroMode = .media
            } else if ExploreDiveSiteDetailPresentation.prefersMapHero(
                hasTaggedMedia: false,
                hasMapPin: hasMap
            ) {
                siteHeroMode = .map
            } else {
                siteHeroMode = .media
            }
            hasCompletedInitialHeroSync = true
        }

        enforceSingleModeHeroWhenToggleHidden()

        if !hasMap, siteHeroMode == .map {
            siteHeroMode = .media
        }

        lastResolvedHadTaggedMedia = hasMedia
    }

    private func enforceSingleModeHeroWhenToggleHidden() {
        let hasMedia = !taggedMediaItems.isEmpty
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
        guard !taggedMediaItems.isEmpty else {
            heroTaggedMediaID = nil
            return
        }
        if let heroTaggedMediaID,
           taggedMediaItems.contains(where: { $0.id == heroTaggedMediaID }) {
            return
        }
        heroTaggedMediaID = ExploreDiveSiteDetailPresentation.initialHeroTaggedMediaPhotoID(
            from: taggedMediaItems
        )
    }

    /// Sentinel **`ownerProfileID`** so **`@Query`** returns no dives when signed out.
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
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
