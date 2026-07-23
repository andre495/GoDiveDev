import Foundation

/// Copy + payload keys for friend-invite accepted push notifications.
enum GoDiveFriendInvitePushPresentation: Sendable {
    nonisolated static let notificationType = "friend_invite_accepted"
    nonisolated static let friendUIDKey = "friendUID"

    nonisolated static func notificationTitle() -> String {
        "New friend on GoDive"
    }

    nonisolated static func notificationBody(friendDisplayName: String) -> String {
        let name = friendDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "A diver" : name
        return "\(label) accepted your invite."
    }
}

/// Pure trigger for Cloud Functions / tests.
enum GoDiveFriendInvitePushTrigger: Sendable {
    nonisolated static func shouldNotifyInviteAccepted(
        beforeStatus: String?,
        afterStatus: String?
    ) -> Bool {
        guard afterStatus == GoDiveFriendInviteMapping.inviteStatusRedeemed else { return false }
        guard beforeStatus != afterStatus else { return false }
        return true
    }
}
