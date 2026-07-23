import Foundation

/// After a successful invite redeem, routes the redeemer to the inviter's **`FriendProfileView`**.
enum GoDiveFriendInvitePostRedeemNavigation: Sendable {
    nonisolated static let openFriendProfileNotification = Notification.Name(
        "GoDive.openFriendProfileAfterInviteRedeem"
    )

    @MainActor
    static func scheduleOpenFriendProfile(_ profile: GoDiveFriendGraphService.PublicProfileSummary) {
        GoDiveFriendInvitePostRedeemNavigationStore.shared.setPending(profile)
        NotificationCenter.default.post(name: openFriendProfileNotification, object: nil)
    }
}

@MainActor
final class GoDiveFriendInvitePostRedeemNavigationStore {
    static let shared = GoDiveFriendInvitePostRedeemNavigationStore()

    private(set) var pendingFriend: GoDiveFriendGraphService.FriendEdge?

    private init() {}

    func setPending(_ profile: GoDiveFriendGraphService.PublicProfileSummary) {
        pendingFriend = GoDiveFriendGraphService.friendEdge(
            friendUID: profile.uid,
            displayName: profile.displayName,
            photoURL: profile.photoURL,
            profileHeroURL: profile.profileHeroURL,
            profileHeroMediaKind: profile.profileHeroMediaKind
        )
    }

    func consumePendingFriend() -> GoDiveFriendGraphService.FriendEdge? {
        let edge = pendingFriend
        pendingFriend = nil
        return edge
    }

    func clear() {
        pendingFriend = nil
    }
}
