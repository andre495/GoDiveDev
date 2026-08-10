import Foundation
import SwiftData

/// In-memory snorkel buddy tagging — apply to SwiftData once on **Done**.
enum SnorkelBuddyActivityTagDraftPresentation {

    nonisolated static func taggedBuddyIDs(on activity: SnorkelActivity) -> Set<UUID> {
        Set(activity.buddies.compactMap(\.buddyID))
    }

    static func apply(
        draftTaggedBuddyIDs: Set<UUID>,
        to activity: SnorkelActivity,
        rosterByID: [UUID: DiveBuddy],
        modelContext: ModelContext
    ) {
        let current = taggedBuddyIDs(on: activity)
        let toRemove = current.subtracting(draftTaggedBuddyIDs)
        let toAdd = draftTaggedBuddyIDs.subtracting(current)

        for buddyID in toRemove {
            guard let tag = activity.buddies.first(where: { $0.buddyID == buddyID }) else { continue }
            SnorkelBuddyActivityAssociation.removeTag(tag, from: activity, modelContext: modelContext)
        }

        for buddyID in toAdd {
            guard let buddy = rosterByID[buddyID] else { continue }
            SnorkelBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: modelContext)
        }
    }
}
