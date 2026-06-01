import Foundation
import SwiftData

/// Replaces in-memory import buddy labels with roster **`DiveBuddy`** rows before insert.
enum DiveBuddyImportConsolidation {

    /// In-memory roster keyed by **`DiveBuddyCatalog.normalizedNameKey`** for the current import batch.
    typealias RosterCache = [String: DiveBuddy]

    /// Decode-time tag: name only (no persisted **`DiveBuddy`**, no **`dive`** inverse link).
    static func makePendingTag(displayName: String, tagID: UUID = UUID()) -> DiveBuddyTag {
        let placeholder = DiveBuddy(displayName: displayName)
        let tag = DiveBuddyTag(id: tagID, buddy: placeholder, dive: nil)
        tag.buddy = nil
        tag.buddyID = nil
        tag.legacyDisplayName = displayName
        return tag
    }

    /// Links each pending buddy on **`activity`** to an existing roster person or creates one.
    static func prepareForInsert(
        _ activity: DiveActivity,
        owner: UserProfile?,
        modelContext: ModelContext,
        rosterCache: inout RosterCache
    ) {
        let pending = activity.buddies
        guard !pending.isEmpty else { return }

        detachPendingTags(pending, from: activity)

        for tag in pending {
            let name = tag.displayName
            let tagID = tag.id
            _ = DiveBuddyActivityAssociation.tagNewBuddy(
                displayName: name,
                owner: owner,
                on: activity,
                modelContext: modelContext,
                tagID: tagID,
                rosterCache: &rosterCache
            )
        }
    }

    /// Clears pending rows so **`insert(activity)`** does not cascade transient **`DiveBuddy`** rows.
    private static func detachPendingTags(_ pending: [DiveBuddyTag], from activity: DiveActivity) {
        activity.buddies = []
        for tag in pending {
            tag.dive = nil
            tag.diveActivityID = nil
            tag.buddy = nil
            tag.buddyID = nil
        }
    }
}
