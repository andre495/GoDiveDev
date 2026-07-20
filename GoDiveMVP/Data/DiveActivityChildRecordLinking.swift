import Foundation

/// Keeps denormalized **`diveActivityID`** in sync when child rows are linked after **`init`**.
/// SwiftData **`@Relationship`** setters do not reliably run custom **`didSet`** observers.
enum DiveActivityChildRecordLinking {

    static func link(_ tag: DiveBuddyTag, to dive: DiveActivity) {
        tag.diveActivityID = dive.id
        tag.dive = dive
    }

    static func link(_ point: DiveProfilePoint, to dive: DiveActivity) {
        point.diveActivityID = dive.id
    }

    static func link(_ photo: DiveMediaPhoto, to dive: DiveActivity) {
        photo.diveActivityID = dive.id
        photo.dive = dive
    }

    static func link(_ tag: DiveMediaBuddyTag, to media: DiveMediaPhoto) {
        tag.mediaPhotoID = media.id
        tag.mediaPhoto = media
        if tag.diveActivityID == nil {
            tag.diveActivityID = media.diveActivityID
        }
    }

    static func link(_ tag: DiveMediaBuddyTag, to dive: DiveActivity) {
        tag.diveActivityID = dive.id
        tag.diveActivity = dive
    }
}
