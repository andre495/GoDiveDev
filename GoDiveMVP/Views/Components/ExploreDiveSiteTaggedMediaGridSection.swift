import SwiftData
import SwiftUI

/// Dive-site tagged media — **`LinkedMediaGridSection`** (same grid + fullscreen as trip / species).
struct ExploreDiveSiteTaggedMediaGridSection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let sightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let onOpenDive: (UUID) -> Void

    var body: some View {
        LinkedMediaGridSection(
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
            linkedMediaItems: linkedMediaItems,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            featuredMediaPhotoID: nil,
            onToggleFeaturedTaggedMedia: nil,
            sightings: sightings,
            marineLifeCatalog: marineLifeCatalog,
            ownerProfileID: ownerProfileID,
            fullscreenConfiguration: .diveSite,
            gridAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.Grid",
            gridItemAccessibilityPrefix: "Explore.DiveSiteDetail.TaggedMedia.Grid.Item",
            sectionAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia",
            emptyMessage: ExploreDiveSiteDetailContentPagerPresentation.emptyStateMessage(for: .taggedMedia),
            emptyAccessibilityIdentifier: "Explore.DiveSiteDetail.TaggedMedia.Empty",
            onOpenDive: onOpenDive
        )
    }
}
