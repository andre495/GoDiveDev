import Foundation
import SwiftData

/// Join row tagging a **`DiveBuddy`** on a **`DiveMediaPhoto`**.
@Model
final class DiveMediaBuddyTag {

    var id: UUID = UUID()

    /// Denormalized for batch **`delete(model:where:)`**.
    var mediaPhotoID: UUID?

    /// Denormalized for batch deletes / predicates.
    var buddyID: UUID?

    /// Denormalized parent dive for cleanup and queries.
    var diveActivityID: UUID?

    var snorkelActivityID: UUID?

    @Relationship(inverse: \DiveBuddy.mediaBuddyTagsStorage)
    var buddy: DiveBuddy?

    @Relationship(inverse: \DiveMediaPhoto.mediaBuddyTagsStorage)
    var mediaPhoto: DiveMediaPhoto?

    @Relationship(inverse: \SnorkelMediaPhoto.mediaBuddyTagsStorage)
    var snorkelMediaPhoto: SnorkelMediaPhoto?

    @Relationship(inverse: \DiveActivity.mediaBuddyTagsStorage)
    var diveActivity: DiveActivity?

    @Relationship(inverse: \SnorkelActivity.mediaBuddyTagsStorage)
    var snorkelActivity: SnorkelActivity?

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

    init(
        id: UUID = UUID(),
        buddy: DiveBuddy,
        snorkelMediaPhoto: SnorkelMediaPhoto,
        snorkelActivity: SnorkelActivity
    ) {
        self.id = id
        self.buddy = buddy
        self.buddyID = buddy.id
        self.snorkelMediaPhoto = snorkelMediaPhoto
        self.mediaPhotoID = snorkelMediaPhoto.id
        self.snorkelActivity = snorkelActivity
        self.snorkelActivityID = snorkelActivity.id
    }
}
