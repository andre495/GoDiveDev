import Foundation
import SwiftData

enum SnorkelBuddyImportConsolidation {

    typealias RosterCache = [String: DiveBuddy]

    static func makePendingTag(displayName: String, tagID: UUID = UUID()) -> SnorkelBuddyTag {
        let placeholder = DiveBuddy(displayName: displayName)
        let tag = SnorkelBuddyTag(id: tagID, buddy: placeholder, snorkelActivity: nil)
        tag.buddy = nil
        tag.buddyID = nil
        tag.legacyDisplayName = displayName
        return tag
    }

    static func prepareForInsert(
        _ activity: SnorkelActivity,
        owner: UserProfile?,
        modelContext: ModelContext,
        rosterCache: inout RosterCache
    ) {
        let pending = activity.buddies
        guard !pending.isEmpty else { return }

        activity.buddies = []
        for tag in pending {
            tag.snorkelActivity = nil
            tag.snorkelActivityID = nil
            tag.buddy = nil
            tag.buddyID = nil
        }

        for tag in pending {
            let name = tag.displayName
            let tagID = tag.id
            _ = SnorkelBuddyActivityAssociation.tagNewBuddy(
                displayName: name,
                owner: owner,
                on: activity,
                modelContext: modelContext,
                tagID: tagID,
                rosterCache: &rosterCache
            )
        }
    }
}

enum SnorkelBuddyActivityAssociation {

    @discardableResult
    static func tagBuddy(
        _ buddy: DiveBuddy,
        on activity: SnorkelActivity,
        modelContext: ModelContext,
        tagID: UUID = UUID()
    ) -> SnorkelBuddyTag? {
        guard !isBuddyTagged(buddyID: buddy.id, on: activity) else { return nil }
        let tag = SnorkelBuddyTag(id: tagID, buddy: buddy, snorkelActivity: activity)
        modelContext.insert(tag)
        tag.link(to: activity)
        activity.buddies.append(tag)
        buddy.snorkelParticipations.append(tag)
        GoDiveFriendBuddyLinking.scheduleAutoLinkAfterBuddyTagged(buddy, modelContext: modelContext)
        return tag
    }

    @discardableResult
    static func tagNewBuddy(
        displayName: String,
        owner: UserProfile?,
        on activity: SnorkelActivity,
        modelContext: ModelContext,
        tagID: UUID,
        rosterCache: inout SnorkelBuddyImportConsolidation.RosterCache
    ) -> SnorkelBuddyTag? {
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }
        let buddy = DiveBuddyCatalog.findOrCreate(
            displayName: displayName,
            owner: owner,
            modelContext: modelContext,
            rosterCache: &rosterCache
        )
        return tagBuddy(buddy, on: activity, modelContext: modelContext, tagID: tagID)
    }

    static func isBuddyTagged(buddyID: UUID, on activity: SnorkelActivity) -> Bool {
        activity.buddies.contains { $0.buddyID == buddyID }
    }

    static func removeTag(
        _ tag: SnorkelBuddyTag,
        from activity: SnorkelActivity,
        modelContext: ModelContext
    ) {
        activity.buddies.removeAll { $0.id == tag.id }
        tag.buddy?.snorkelParticipations.removeAll { $0.id == tag.id }
        modelContext.delete(tag)
    }
}
