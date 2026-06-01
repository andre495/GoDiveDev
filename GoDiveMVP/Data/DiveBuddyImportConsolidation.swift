import Foundation
import SwiftData

/// Replaces in-memory import buddies with roster **`DiveBuddy`** rows before insert.
enum DiveBuddyImportConsolidation {
    static func prepareForInsert(
        _ activity: DiveActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) {
        let pending = activity.buddies
        guard !pending.isEmpty else { return }
        activity.buddies = []
        for tag in pending {
            let name = tag.displayName
            let tagID = tag.id
            _ = DiveBuddyActivityAssociation.tagNewBuddy(
                displayName: name,
                owner: owner,
                on: activity,
                modelContext: modelContext,
                tagID: tagID
            )
        }
    }
}
