import Foundation
import SwiftData

/// Tags **`DiveBuddy`** people on **`DiveActivity`** rows.
enum DiveBuddyActivityAssociation {

    @discardableResult
    static func tagBuddy(
        _ buddy: DiveBuddy,
        on activity: DiveActivity,
        modelContext: ModelContext,
        tagID: UUID = UUID()
    ) -> DiveBuddyTag? {
        guard !isBuddyTagged(buddyID: buddy.id, on: activity) else { return nil }
        let tag = DiveBuddyTag(id: tagID, buddy: buddy, dive: activity)
        modelContext.insert(tag)
        tag.link(to: activity)
        activity.buddies.append(tag)
        buddy.diveParticipations.append(tag)
        GoDiveFriendBuddyLinking.scheduleAutoLinkAfterBuddyTagged(buddy, modelContext: modelContext)
        return tag
    }

    @discardableResult
    static func tagNewBuddy(
        displayName: String,
        profilePhoto: Data? = nil,
        contactsIdentifier: String? = nil,
        owner: UserProfile?,
        on activity: DiveActivity,
        modelContext: ModelContext,
        tagID: UUID = UUID()
    ) -> DiveBuddyTag? {
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }
        let buddy = DiveBuddyCatalog.findOrCreate(
            displayName: displayName,
            contactsIdentifier: contactsIdentifier,
            profilePhoto: profilePhoto,
            owner: owner,
            modelContext: modelContext
        )
        return tagBuddy(buddy, on: activity, modelContext: modelContext, tagID: tagID)
    }

    @discardableResult
    static func tagNewBuddy(
        displayName: String,
        owner: UserProfile?,
        on activity: DiveActivity,
        modelContext: ModelContext,
        tagID: UUID,
        rosterCache: inout DiveBuddyImportConsolidation.RosterCache
    ) -> DiveBuddyTag? {
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }
        let buddy = DiveBuddyCatalog.findOrCreate(
            displayName: displayName,
            owner: owner,
            modelContext: modelContext,
            rosterCache: &rosterCache
        )
        return tagBuddy(buddy, on: activity, modelContext: modelContext, tagID: tagID)
    }

    static func isBuddyTagged(buddyID: UUID, on activity: DiveActivity) -> Bool {
        activity.buddies.contains { $0.buddyID == buddyID }
    }

    /// Removes participation on this dive only; **`DiveBuddy`** row is kept.
    static func removeTag(_ tag: DiveBuddyTag, from activity: DiveActivity, modelContext: ModelContext) {
        activity.buddies.removeAll { $0.id == tag.id }
        tag.buddy?.diveParticipations.removeAll { $0.id == tag.id }
        modelContext.delete(tag)
    }
}
