import SwiftUI

/// Swipable tag detail pages — stats → activities → marine life → buddies → media.
struct ActivityTagDetailContentPager: View {
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
    @Binding var gallerySelectedMediaID: UUID?
    let bottomScrollInset: CGFloat
    let onOpenDive: (UUID) -> Void

    @State private var selectedPage: ActivityTagDetailContentPage =
        ActivityTagDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "ActivityTagDetails.ContentPager",
            pages: ActivityTagDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            usesLazyMount: false,
            pageLayout: ActivityTagDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: ActivityTagDetailContentPage) -> some View {
        switch page {
        case .stats:
            TripDetailTripStatsSection(
                tiles: statTiles,
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("ActivityTagDetails.Stats")
        case .activities:
            linkedDivesSection
        case .marineLife:
            TripDetailMarineLifeSection(
                items: marineLifeItems,
                marineLifeCatalog: marineLifeCatalog,
                unitSystem: unitSystem,
                ownerProfileID: ownerProfileID,
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("ActivityTagDetails.MarineLife")
        case .buddies:
            TripDetailBuddiesSection(
                buddies: aggregate.buddies,
                rosterBuddiesByID: rosterBuddiesByID,
                ownerProfile: ownerProfile
            )
            .accessibilityIdentifier("ActivityTagDetails.Buddies")
        case .media:
            TripDetailMediaGallerySection(
                mediaItems: mediaItems,
                timeZoneOffsetByMediaID: mediaTimeZoneOffsets,
                linkedMediaItems: linkedMediaItems,
                sightings: mediaSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                featuredMediaPhotoID: nil,
                selectedMediaID: $gallerySelectedMediaID,
                onToggleFeaturedTripMedia: nil,
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("ActivityTagDetails.Media")
        }
    }

    @ViewBuilder
    private var linkedDivesSection: some View {
        if linkedDiveRows.isEmpty {
            Text("No dives use this tag yet.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("ActivityTagDetails.LinkedDives.Empty")
        } else {
            LinkedDiveLogbookListRows(
                rows: linkedDiveRows,
                listAccessibilityIdentifier: "ActivityTagDetails.DiveList",
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("ActivityTagDetails.LinkedDives")
        }
    }
}
