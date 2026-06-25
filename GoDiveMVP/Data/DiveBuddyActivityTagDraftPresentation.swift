import Foundation
import SwiftData

/// In-memory dive buddy tagging — apply to SwiftData once on **Done**.
enum DiveBuddyActivityTagDraftPresentation {

    nonisolated static func taggedBuddyIDs(on activity: DiveActivity) -> Set<UUID> {
        Set(activity.buddies.compactMap(\.buddyID))
    }

    static func apply(
        draftTaggedBuddyIDs: Set<UUID>,
        to activity: DiveActivity,
        rosterByID: [UUID: DiveBuddy],
        modelContext: ModelContext
    ) {
        let current = taggedBuddyIDs(on: activity)
        let toRemove = current.subtracting(draftTaggedBuddyIDs)
        let toAdd = draftTaggedBuddyIDs.subtracting(current)

        for buddyID in toRemove {
            guard let tag = activity.buddies.first(where: { $0.buddyID == buddyID }) else { continue }
            DiveBuddyActivityAssociation.removeTag(tag, from: activity, modelContext: modelContext)
        }

        for buddyID in toAdd {
            guard let buddy = rosterByID[buddyID] else { continue }
            DiveBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: modelContext)
        }
    }
}
