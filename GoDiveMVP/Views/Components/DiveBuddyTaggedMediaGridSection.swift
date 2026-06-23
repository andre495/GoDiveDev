import SwiftUI

/// Buddy tagged media — thin wrapper around **`LinkedMediaGridSection`**.
struct DiveBuddyTaggedMediaGridSection: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let featuredMediaPhotoID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let onToggleFeaturedTaggedMedia: (() -> Void)?

    var body: some View {
        LinkedMediaGridSection(
            mediaItems: mediaItems,
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID,
            linkedMediaItems: linkedMediaItems,
            gallerySelectedMediaID: $gallerySelectedMediaID,
            featuredMediaPhotoID: featuredMediaPhotoID,
            onToggleFeaturedTaggedMedia: onToggleFeaturedTaggedMedia,
            sightings: [],
            marineLifeCatalog: [],
            ownerProfileID: nil,
            fullscreenConfiguration: .buddy,
            gridAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia.Grid",
            gridItemAccessibilityPrefix: "DiveBuddyDetails.TaggedMedia.Grid.Item",
            sectionAccessibilityIdentifier: "DiveBuddyDetails.TaggedMedia",
            emptyMessage: nil,
            emptyAccessibilityIdentifier: nil,
            onOpenDive: { _ in }
        )
    }
}
