import Foundation
import SwiftData

/// Breaks SwiftData **non-cascade** relationship inverses on a **`SnorkelActivity`** before delete.
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
    }
}
