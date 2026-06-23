import SwiftUI

/// Trip linked media — 3-column grid + full-screen viewer (same pattern as buddy tagged media).
struct TripDetailMediaGallerySection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let featuredMediaPhotoID: UUID?
    var selectedMediaID: Binding<UUID?>?
    var initialSelectedMediaID: UUID?
    var onToggleFeaturedTripMedia: (() -> Void)?
    var onOpenDive: (UUID) -> Void

    @State private var internalSelectedMediaID: UUID?

    private var activeSelectedMediaID: Binding<UUID?> {
        selectedMediaID ?? $internalSelectedMediaID
    }

    var body: some View {
        LinkedMediaGridSection(
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
            linkedMediaItems: linkedMediaItems,
            gallerySelectedMediaID: activeSelectedMediaID,
            featuredMediaPhotoID: featuredMediaPhotoID,
            onToggleFeaturedTaggedMedia: onToggleFeaturedTripMedia,
            sightings: sightings,
            marineLifeCatalog: marineLifeCatalog,
            ownerProfileID: ownerProfileID,
            fullscreenConfiguration: .trip,
            gridAccessibilityIdentifier: "TripDetail.Media.Grid",
            gridItemAccessibilityPrefix: "TripDetail.Media.Grid.Item",
            sectionAccessibilityIdentifier: "TripDetail.MediaSection",
            emptyMessage: DiveTripPresentation.tripMediaEmptyMessage,
            emptyAccessibilityIdentifier: "TripDetail.Media.Empty",
            initialFullscreenMediaID: initialSelectedMediaID,
            onOpenDive: onOpenDive
        )
    }
}
