import Foundation
import SwiftData

/// Breaks SwiftData **non-cascade** relationship inverses on a **`SnorkelActivity`** so the row can be deleted.
///
/// Join rows that also invert onto **`DiveBuddy`** (**`SnorkelBuddyTag`**, **`DiveMediaBuddyTag`**) are deleted
/// here — the same pattern as **`DiveActivityRelationshipDetachment`** for trip links / equipment.
/// Cascade children (**`mediaPhotos`**, **`marineLifeSightings`**) are then removed by batch delete +
/// **`modelContext.delete(activity)`**.
/// **`SnorkelProfilePoint`** rows live in the user-local store and are deleted separately via
/// **`SnorkelProfilePointStore.deletePoints`**.
enum SnorkelActivityRelationshipDetachment {

    nonisolated static func detachNonCascadeRelationships(
        from activity: SnorkelActivity,
        modelContext: ModelContext
    ) {
        let activityID = activity.id

        let linkedTags = activity.activityTags
        for tag in linkedTags {
            tag.snorkels.removeAll { $0.id == activityID }
        }
        activity.activityTags.removeAll()

        if let owner = activity.owner {
            owner.snorkelActivities.removeAll { $0.id == activityID }
        }
        activity.owner = nil
        activity.diveSiteID = nil

        let buddyTags = activity.buddies
        for tag in buddyTags {
            if let buddy = tag.buddy {
                buddy.snorkelParticipations.removeAll { $0.id == tag.id }
            }
            tag.buddy = nil
            tag.snorkelActivity = nil
            modelContext.delete(tag)
        }
        activity.buddies.removeAll()

        let mediaBuddyTags = activity.mediaBuddyTags
        for tag in mediaBuddyTags {
            if let buddy = tag.buddy {
                buddy.mediaBuddyTags.removeAll { $0.id == tag.id }
            }
            if let media = tag.snorkelMediaPhoto {
                media.mediaBuddyTags.removeAll { $0.id == tag.id }
            }
            tag.buddy = nil
            tag.snorkelMediaPhoto = nil
            tag.snorkelActivity = nil
            modelContext.delete(tag)
        }
        activity.mediaBuddyTags.removeAll()

        let sightings = activity.marineLifeSightings
        for sighting in sightings {
            if let media = sighting.snorkelMediaPhoto {
                media.marineLifeSightings.removeAll { $0.sightingUUID == sighting.sightingUUID }
            }
            sighting.snorkelMediaPhoto = nil
        }
        activity.marineLifeSightings.removeAll()
        activity.mediaPhotos.removeAll()
    }
}
