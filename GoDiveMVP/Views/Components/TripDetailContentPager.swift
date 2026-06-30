import SwiftUI

/// Swipable trip detail pages — planned (sites + buddies) or active (stats → media).
struct TripDetailContentPager: View {
    let trip: DiveTrip
    let hasStarted: Bool
    let statTiles: [DiveTripStatTile]
    let aggregate: DiveTripAggregate
    let linkedDiveRows: [DiveLogbookRowDisplayData]
    let marineLifeItems: [TripDetailMarineLifeCarouselItem]
    let marineLifeCatalog: [MarineLife]
    let unitSystem: DiveDisplayUnitSystem
    let ownerProfileID: UUID?
    let ownerProfile: UserProfile?
    let rosterBuddiesByID: [UUID: DiveBuddy]
    let mediaItems: [DiveMediaPhoto]
    let mediaTimeZoneOffsets: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let featuredTripMediaPhotoID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let onToggleFeaturedTripMedia: (() -> Void)?
    let bottomScrollInset: CGFloat
    var initialContentPage: TripDetailContentPage?
    var initialSelectedMediaID: UUID?
    var onOpenDive: (UUID) -> Void

    @State private var selectedPage: TripDetailContentPage

    private var pages: [TripDetailContentPage] {
        TripDetailContentPagerPresentation.pages(hasStarted: hasStarted)
    }

    init(
        trip: DiveTrip,
        hasStarted: Bool,
        statTiles: [DiveTripStatTile],
        aggregate: DiveTripAggregate,
        linkedDiveRows: [DiveLogbookRowDisplayData],
        marineLifeItems: [TripDetailMarineLifeCarouselItem],
        marineLifeCatalog: [MarineLife],
        unitSystem: DiveDisplayUnitSystem,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile?,
        rosterBuddiesByID: [UUID: DiveBuddy],
        mediaItems: [DiveMediaPhoto],
        mediaTimeZoneOffsets: [UUID: Int?],
        linkedMediaItems: [TripDetailLinkedMediaItem],
        mediaSightings: [SightingInstance],
        featuredTripMediaPhotoID: UUID?,
        gallerySelectedMediaID: Binding<UUID?>,
        onToggleFeaturedTripMedia: (() -> Void)?,
        bottomScrollInset: CGFloat,
        initialContentPage: TripDetailContentPage? = nil,
        initialSelectedMediaID: UUID? = nil,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.trip = trip
        self.hasStarted = hasStarted
        self.statTiles = statTiles
        self.aggregate = aggregate
        self.linkedDiveRows = linkedDiveRows
        self.marineLifeItems = marineLifeItems
        self.marineLifeCatalog = marineLifeCatalog
        self.unitSystem = unitSystem
        self.ownerProfileID = ownerProfileID
        self.ownerProfile = ownerProfile
        self.rosterBuddiesByID = rosterBuddiesByID
        self.mediaItems = mediaItems
        self.mediaTimeZoneOffsets = mediaTimeZoneOffsets
        self.linkedMediaItems = linkedMediaItems
        self.mediaSightings = mediaSightings
        self.featuredTripMediaPhotoID = featuredTripMediaPhotoID
        _gallerySelectedMediaID = gallerySelectedMediaID
        self.onToggleFeaturedTripMedia = onToggleFeaturedTripMedia
        self.bottomScrollInset = bottomScrollInset
        self.initialContentPage = initialContentPage
        self.initialSelectedMediaID = initialSelectedMediaID
        self.onOpenDive = onOpenDive
        let initialPage = TripDetailContentPagerPresentation.resolvedInitialPage(
            hasStarted: hasStarted,
            requested: initialContentPage
        )
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "TripDetail.ContentPager",
            pages: pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            usesLazyMount: false,
            pageLayout: TripDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
        .onChange(of: hasStarted) { _, started in
            let nextPages = TripDetailContentPagerPresentation.pages(hasStarted: started)
            if !nextPages.contains(selectedPage) {
                selectedPage = nextPages.first ?? .stats
            }
        }
    }

    @ViewBuilder
    private func pageContent(for page: TripDetailContentPage) -> some View {
        switch page {
        case .plannedSites:
            TripDetailPlannedSitesSection(
                trip: trip,
                ownerProfileID: ownerProfileID,
                onOpenDive: onOpenDive
            )
        case .buddies:
            if hasStarted {
                TripDetailBuddiesSection(
                    buddies: aggregate.buddies,
                    rosterBuddiesByID: rosterBuddiesByID,
                    ownerProfile: ownerProfile
                )
            } else {
                TripDetailPlannedBuddiesSection(
                    trip: trip,
                    ownerProfile: ownerProfile
                )
            }
        case .stats:
            TripDetailTripStatsSection(
                tiles: statTiles,
                onOpenDive: onOpenDive
            )
        case .marineLife:
            TripDetailMarineLifeSection(
                items: marineLifeItems,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: unitSystem,
                ownerProfileID: ownerProfileID,
                onOpenDive: onOpenDive
            )
        case .activities:
            linkedDivesSection
        case .media:
            TripDetailMediaGallerySection(
                mediaItems: mediaItems,
                timeZoneOffsetByMediaID: mediaTimeZoneOffsets,
                linkedMediaItems: linkedMediaItems,
                sightings: mediaSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                featuredMediaPhotoID: featuredTripMediaPhotoID,
                selectedMediaID: $gallerySelectedMediaID,
                initialSelectedMediaID: initialSelectedMediaID,
                onToggleFeaturedTripMedia: onToggleFeaturedTripMedia,
                onOpenDive: onOpenDive
            )
        }
    }

    @ViewBuilder
    private var linkedDivesSection: some View {
        if linkedDiveRows.isEmpty {
            Text(DiveTripPresentation.linkedDivesEmptyMessage)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("TripDetail.LinkedDives.Empty")
        } else {
            LinkedDiveLogbookListRows(
                rows: linkedDiveRows,
                listAccessibilityIdentifier: "TripDetail.LinkedDives.List",
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("TripDetail.LinkedDives")
        }
    }
}
