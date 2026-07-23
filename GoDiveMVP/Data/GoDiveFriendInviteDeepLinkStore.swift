import Foundation
import Observation

/// Holds a pending friend-invite token from a deep link until the signed-in UI can redeem it.
@MainActor
@Observable
final class GoDiveFriendInviteDeepLinkStore {
    static let shared = GoDiveFriendInviteDeepLinkStore()

    private(set) var pendingInviteToken: String?

    func handleIncomingURL(_ url: URL) {
        guard let token = GoDiveFriendInviteURL.inviteToken(from: url) else { return }
        pendingInviteToken = token
    }

    func consumePendingToken() -> String? {
        let token = pendingInviteToken
        pendingInviteToken = nil
        return token
    }

    func clear() {
        pendingInviteToken = nil
    }

    /// Test / preview helper.
    func setPendingTokenForTesting(_ token: String?) {
        pendingInviteToken = token.map(GoDiveFriendInviteURL.normalizedToken)
    }
}
