import Foundation
import SwiftData

/// Auto-tags GoDive friends `@mentioned` in activity notes onto the activity roster.
enum GoDiveNotesMentionTagging: Sendable {
    /// Tags mentioned friends who are not already on the dive (creates/links roster rows as needed).
    @MainActor
    @discardableResult
    static func tagMentionedFriends(
        inNotes notes: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        on activity: DiveActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> Int {
        let mentions = GoDiveMentionPresentation.mentionedFriends(in: notes, friends: friends)
        var taggedCount = 0
        for friend in mentions {
            let uid = friend.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uid.isEmpty else { continue }
            if isFirebaseUIDTagged(uid, on: activity) { continue }
            guard let buddy = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                friendUID: uid,
                displayName: friend.displayName,
                photoURL: friend.photoURL,
                owner: owner,
                modelContext: modelContext
            ) else { continue }
            if DiveBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: modelContext) != nil {
                taggedCount += 1
            }
        }
        return taggedCount
    }

    /// Tags mentioned friends who are not already on the snorkel.
    @MainActor
    @discardableResult
    static func tagMentionedFriends(
        inNotes notes: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        on activity: SnorkelActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> Int {
        let mentions = GoDiveMentionPresentation.mentionedFriends(in: notes, friends: friends)
        var taggedCount = 0
        for friend in mentions {
            let uid = friend.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uid.isEmpty else { continue }
            if isFirebaseUIDTagged(uid, on: activity) { continue }
            guard let buddy = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                friendUID: uid,
                displayName: friend.displayName,
                photoURL: friend.photoURL,
                owner: owner,
                modelContext: modelContext
            ) else { continue }
            if SnorkelBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: modelContext) != nil {
                taggedCount += 1
            }
        }
        return taggedCount
    }

    /// Pure helper for tests — UIDs that would be tagged given current tagged UIDs.
    nonisolated static func friendUIDsNeedingTag(
        notes: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        alreadyTaggedFirebaseUIDs: Set<String>
    ) -> [String] {
        GoDiveMentionPresentation.mentionedFriends(in: notes, friends: friends)
            .map(\.friendUID)
            .filter { !alreadyTaggedFirebaseUIDs.contains($0) }
    }

    @MainActor
    private static func isFirebaseUIDTagged(_ uid: String, on activity: DiveActivity) -> Bool {
        activity.buddies.contains { tag in
            guard let buddy = tag.buddy else { return false }
            return DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) == uid
        }
    }

    @MainActor
    private static func isFirebaseUIDTagged(_ uid: String, on activity: SnorkelActivity) -> Bool {
        activity.buddies.contains { tag in
            guard let buddy = tag.buddy else { return false }
            return DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) == uid
        }
    }
}
