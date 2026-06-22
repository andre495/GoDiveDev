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
    let bottomScrollInset: CGFloat
    var initialContentPage: TripDetailContentPage?
    var initialSelectedMediaID: UUID?
    var onOpenDive: (UUID) -> Void
    var onOpenInDive: (UUID, UUID) -> Void

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
        bottomScrollInset: CGFloat,
        initialContentPage: TripDetailContentPage? = nil,
        initialSelectedMediaID: UUID? = nil,
        onOpenDive: @escaping (UUID) -> Void,
        onOpenInDive: @escaping (UUID, UUID) -> Void
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
        self.bottomScrollInset = bottomScrollInset
        self.initialContentPage = initialContentPage
        self.initialSelectedMediaID = initialSelectedMediaID
        self.onOpenDive = onOpenDive
        self.onOpenInDive = onOpenInDive
        _selectedPage = State(
            initialValue: TripDetailContentPagerPresentation.resolvedInitialPage(
                hasStarted: hasStarted,
                requested: initialContentPage
            )
        )
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(pages) { page in
                pagerScrollPage(page) {
                    pageContent(for: page)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("TripDetail.ContentPager")
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
                ownerProfileID: ownerProfileID
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
                initialSelectedMediaID: initialSelectedMediaID,
                onOpenDive: onOpenDive,
                onOpenInDive: onOpenInDive
            )
        }
    }

    @ViewBuilder
    private func pagerScrollPage<Content: View>(
        _ page: TripDetailContentPage,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if TripDetailContentPagerPresentation.usesStaticPagerLayout(for: page) {
            let contentAlignment = TripDetailContentPagerPresentation.staticPagerContentAlignment(for: page)
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)

                Color.clear
                    .frame(height: bottomScrollInset)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(TripDetailContentPagerPresentation.accessibilityIdentifier(for: page))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Color.clear
                        .frame(height: bottomScrollInset + AppTheme.Spacing.lg)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier(TripDetailContentPagerPresentation.accessibilityIdentifier(for: page))
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
