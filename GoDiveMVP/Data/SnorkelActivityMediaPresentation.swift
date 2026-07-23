import Foundation

enum SnorkelActivityMediaPresentation: Sendable {

    @MainActor
    static func sortedPhotos(_ photos: [SnorkelMediaPhoto]) -> [SnorkelMediaPhoto] {
        photos.sorted { lhs, rhs in
            DiveActivityMediaPresentation.isOrderedBeforeInGallery(lhs, rhs)
        }
    }

    @MainActor
    static func featuredPhotoID(on activity: SnorkelActivity) -> UUID? {
        DiveActivityMediaPresentation.featuredPhotoID(
            in: activity.mediaPhotos,
            explicitFeaturedID: activity.featuredMediaPhotoID
        )
    }

    @MainActor
    static func selectedMedia(
        selectedID: UUID?,
        in items: [SnorkelMediaPhoto]
    ) -> SnorkelMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedID, in: items)
    }
}
