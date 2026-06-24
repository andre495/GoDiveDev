import Foundation

extension Notification.Name {
    /// Posted after **`DiveBuddy`** roster rows change (photo, name, contact link, delete).
    nonisolated static let diveBuddyRosterDidChange = Notification.Name("GoDive.diveBuddyRosterDidChange")
}

enum DiveBuddyRosterChangeNotification {
    nonisolated static func post() {
        NotificationCenter.default.post(name: .diveBuddyRosterDidChange, object: nil)
    }
}

/// Cheap fingerprint for **`@Query`** buddy rows (photo/name) so Home can rebuild without a full app restart.
enum HomeBuddyRosterRefreshToken {
    nonisolated static func fingerprint(
        buddies: [HomeBuddyRosterRefreshToken.BuddyRow]
    ) -> Int {
        var hasher = Hasher()
        for buddy in buddies.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(buddy.id)
            hasher.combine(buddy.displayName)
            hasher.combine(ProfileAvatarImageCachePresentation.cacheKey(for: buddy.profilePhoto ?? Data()))
        }
        return hasher.finalize()
    }

    struct BuddyRow: Sendable, Equatable {
        let id: UUID
        let displayName: String
        let profilePhoto: Data?
    }
}
