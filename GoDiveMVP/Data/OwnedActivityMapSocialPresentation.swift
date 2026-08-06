import Foundation

/// When to show Buddy Feed–style like/comment chrome on an **owned** activity Map panel.
enum OwnedActivityMapSocialPresentation: Sendable {
    /// Activity is published to friends and the owner has a Firebase UID for `sharedDives` paths.
    nonisolated static func shouldShowSocial(
        isPublishedWithFriends: Bool,
        firebaseUID: String?
    ) -> Bool {
        guard isPublishedWithFriends else { return false }
        let uid = firebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !uid.isEmpty
    }

    /// Owners view tallies but cannot like their own shared activity (rules + client).
    nonisolated static let allowsOwnerLiking = false
}
