import Foundation

/// Keeps denormalized **`diveActivityID`** in sync when child rows are linked after **`init`**.
/// SwiftData **`@Relationship`** setters do not reliably run custom **`didSet`** observers.
enum DiveActivityChildRecordLinking {

    static func link(_ buddy: DiveBuddyTag, to dive: DiveActivity) {
        buddy.diveActivityID = dive.id
        buddy.dive = dive
    }

    static func link(_ point: DiveProfilePoint, to dive: DiveActivity) {
        point.diveActivityID = dive.id
        point.dive = dive
    }

    static func link(_ photo: DiveMediaPhoto, to dive: DiveActivity) {
        photo.diveActivityID = dive.id
        photo.dive = dive
    }
}
