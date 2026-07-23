import Foundation

/// Navigation + copy when a **`DiveBuddy`** row represents a GoDive friend.
enum DiveBuddyFriendLinkPresentation: Sendable {
    nonisolated static func linkedFirebaseUID(for buddy: DiveBuddy) -> String? {
        let trimmed = buddy.linkedFirebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func isLinkedFriend(_ buddy: DiveBuddy) -> Bool {
        linkedFirebaseUID(for: buddy) != nil
    }

    nonisolated static func friendEdge(for buddy: DiveBuddy) -> GoDiveFriendGraphService.FriendEdge? {
        guard let uid = linkedFirebaseUID(for: buddy) else { return nil }
        return GoDiveFriendGraphService.friendEdge(
            friendUID: uid,
            displayName: buddy.displayName,
            photoURL: buddy.linkedPhotoURL
        )
    }
}
