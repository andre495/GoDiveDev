import Foundation
import SwiftData

/// Breaks SwiftData **non-cascade** relationship inverses on a **`DiveActivity`** so the row can be deleted.
///
/// Cascade children (**`profilePoints`**, **`buddies`**, **`mediaPhotos`**, **`marineLifeSightings`**) are **not**
/// touched here — iterating them would fault thousands of FIT samples into memory for no benefit; they are removed by
/// **`modelContext.delete(activity)`** + **`deleteRule: .cascade`** on the parent.
enum DiveActivityRelationshipDetachment {

    nonisolated static func detachNonCascadeRelationships(from activity: DiveActivity) {
        let activityID = activity.id

        let linkedTags = activity.activityTags
        for tag in linkedTags {
            tag.dives.removeAll { $0.id == activityID }
        }
        activity.activityTags.removeAll()

        if let equipmentList = activity.equipmentList {
            for entry in equipmentList.entries {
                entry.equipmentList = nil
            }
            equipmentList.entries.removeAll()
            equipmentList.dive = nil
        }
        activity.equipmentList = nil

        if let owner = activity.owner {
            owner.diveActivities.removeAll { $0.id == activityID }
        }
        activity.owner = nil

        if let linkedSite = activity.diveSite {
            linkedSite.diveActivities.removeAll { $0.id == activityID }
        }
        activity.diveSite = nil
        activity.diveSiteID = nil
    }
}
