import Foundation

/// User-facing copy for Friends / invite / share settings.
enum GoDiveFriendsPresentation: Sendable {
    nonisolated static let listTitle = "Buddies"
    nonisolated static let emptyTitle = "No friends yet"
    nonisolated static let emptyMessage =
        "Share a QR code or link so another GoDive diver can connect with you."
    nonisolated static let addFriendAccessibilityLabel = "Invite a friend"
    nonisolated static let inviteSheetTitle = "Invite a friend"
    nonisolated static let shareLinkButtonTitle = "Share link"
    nonisolated static let copyLinkButtonTitle = "Copy link"
    nonisolated static let revokeInviteButtonTitle = "Revoke invite"
    nonisolated static let redeemTitle = "Connect as friends?"
    nonisolated static let redeemConfirmButtonTitle = "Connect"
    nonisolated static let redeemCancelButtonTitle = "Not now"
    nonisolated static let unfriendButtonTitle = "Unfriend"
    nonisolated static let unfriendConfirmTitle = "Remove friend?"
    nonisolated static let sharedLogbookTitle = "Shared dives"
    nonisolated static let sharedLogbookEmptyTitle = "No shared dives yet"
    nonisolated static let sharedLogbookEmptyMessage =
        "When your friend shares their logbook, their dives appear here. Notes and photos stay private unless they opt in."
    nonisolated static let notesHiddenLabel = "Notes not shared"
    nonisolated static let mediaHiddenLabel = "Photos not shared"
    nonisolated static let firebaseUnavailableMessage =
        "Friends need a network connection and Sign in with Apple social features enabled."
    nonisolated static let taggedYouLabel = "You were tagged on this dive"

    enum ShareDives {
        nonisolated static let title = "Share dives with friends"
        nonisolated static let infoMessage =
            "When on, friends can see your dive details (site, depth, duration, conditions, and more). Your private CloudKit log stays the source of truth; a friend-visible copy is stored for them to read. Notes and media stay off unless you enable those toggles."
    }

    enum ShareNotes {
        nonisolated static let title = "Share notes with friends"
        nonisolated static let infoMessage =
            "When on, dive notes are included in what friends can see. Off by default."
    }

    enum ShareMedia {
        nonisolated static let title = "Share media with friends"
        nonisolated static let infoMessage =
            "When on, small photo previews from your dives upload so friends can see them. Full originals stay in your Photos library. Off by default."
    }

    nonisolated static func friendCountLabel(_ count: Int) -> String {
        count == 1 ? "1 friend" : "\(count) friends"
    }

    nonisolated static func redeemMessage(displayName: String) -> String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "this diver" : name
        return "Connect with \(label)? You’ll be able to see each other’s shared dive details."
    }

    nonisolated static func redeemFailureMessage(
        _ error: GoDiveFriendInviteMapping.RedeemValidationError
    ) -> String {
        switch error {
        case .inviteMissing:
            return "This invite link is invalid."
        case .inviteNotOpen:
            return "This invite was already used or revoked."
        case .inviteExpired:
            return "This invite has expired. Ask your friend for a new link."
        case .selfInvite:
            return "You can’t redeem your own invite."
        case .alreadyFriends:
            return "You’re already friends."
        case .friendCapReached:
            return "You’ve reached the friend limit."
        }
    }
}
