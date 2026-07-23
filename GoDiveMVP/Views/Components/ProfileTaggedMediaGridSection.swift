import SwiftUI

/// Profile tagged media — thin wrapper around **`LinkedMediaGridSection`**.
struct ProfileTaggedMediaGridSection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    var sightings: [SightingInstance] = []
    var marineLifeCatalog: [MarineLife] = []
    var ownerProfileID: UUID? = nil
    let featuredMediaPhotoID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let onToggleFeaturedTaggedMedia: (() -> Void)?
    var onOpenDive: (UUID) -> Void = { _ in }

    var body: some View {
        LinkedMediaGridSection(
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
            linkedMediaItems: linkedMediaItems,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            featuredMediaPhotoID: featuredMediaPhotoID,
            onToggleFeaturedTaggedMedia: onToggleFeaturedTaggedMedia,
            sightings: sightings,
            marineLifeCatalog: marineLifeCatalog,
            ownerProfileID: ownerProfileID,
            buddyTaggedMediaIDs: Set(mediaItems.map(\.id)),
            fullscreenConfiguration: .buddy,
            gridAccessibilityIdentifier: "Profile.TaggedMedia.Grid",
            gridItemAccessibilityPrefix: "Profile.TaggedMedia.Grid.Item",
            sectionAccessibilityIdentifier: "Profile.TaggedMedia",
            emptyMessage: nil,
            emptyAccessibilityIdentifier: nil,
            onOpenDive: onOpenDive
        )
    }
}
