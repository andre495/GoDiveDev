import Foundation
import SwiftData

/// Join row tagging a **`DiveBuddy`** on a **`DiveMediaPhoto`**.
@Model
final class DiveMediaBuddyTag {

    var id: UUID

    /// Denormalized for batch **`delete(model:where:)`**.
    var mediaPhotoID: UUID?

    /// Denormalized for batch deletes / predicates.
    var buddyID: UUID?

    /// Denormalized parent dive for cleanup and queries.
    var diveActivityID: UUID?

    @Relationship(inverse: \DiveBuddy.mediaBuddyTags)
    var buddy: DiveBuddy?

    @Relationship
    var mediaPhoto: DiveMediaPhoto?

    @Relationship(inverse: \DiveActivity.mediaBuddyTags)
    var diveActivity: DiveActivity?

    init(
        id: UUID = UUID(),
        buddy: DiveBuddy,
        mediaPhoto: DiveMediaPhoto? = nil,
        diveActivity: DiveActivity? = nil
    ) {
        self.id = id
        self.buddy = buddy
        self.buddyID = buddy.id
        self.mediaPhoto = mediaPhoto
        self.mediaPhotoID = mediaPhoto?.id
        self.diveActivity = diveActivity ?? mediaPhoto?.dive
        self.diveActivityID = diveActivity?.id ?? mediaPhoto?.diveActivityID
    }
}
