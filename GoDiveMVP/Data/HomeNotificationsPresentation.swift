import Foundation

/// Home bell → **Notifications** list. Items derive from Firestore social data
/// (friendship `since` dates + friend-shared activities), so the list matches
/// what pushes announced even when a push was never delivered to this device.
enum HomeNotificationsPresentation: Sendable {
    nonisolated static let pageTitle = "Notifications"
    nonisolated static let maxItems = 100
    nonisolated static let emptyStateMessage = "No notifications yet. When buddies connect or share new activities, they show up here."
    nonisolated static let bellAccessibilityIdentifier = "Home.NotificationsBell"

    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case friendConnected(GoDiveFriendGraphService.FriendEdge)
            case buddyActivityShared(LogbookBuddyFeedPresentation.Row)
            case buddyActivityTaggedYou(LogbookBuddyFeedPresentation.Row)
        }

        var id: String
        var kind: Kind
        var date: Date
        var friendDisplayName: String
        var friendPhotoURL: String?
        var message: String
        /// Secondary line (site name for activities).
        var detail: String?
    }

    /// Merged newest-first notification items from the buddy feed snapshot.
    nonisolated static func items(
        friends: [GoDiveFriendGraphService.FriendEdge],
        activityRows: [LogbookBuddyFeedPresentation.Row],
        currentFirebaseUID: String? = nil
    ) -> [Item] {
        var merged: [Item] = []
        merged.reserveCapacity(friends.count + activityRows.count * 2)

        for friend in friends {
            guard let since = friend.since else { continue }
            merged.append(
                Item(
                    id: "friend-\(friend.friendUID)",
                    kind: .friendConnected(friend),
                    date: since,
                    friendDisplayName: friend.displayName,
                    friendPhotoURL: friend.photoURL,
                    message: friendConnectedMessage(displayName: friend.displayName),
                    detail: nil
                )
            )
        }

        for row in activityRows {
            merged.append(
                Item(
                    id: "activity-\(row.id)",
                    kind: .buddyActivityShared(row),
                    date: activityDate(for: row.dive),
                    friendDisplayName: row.friendDisplayName,
                    friendPhotoURL: row.friendPhotoURL,
                    message: activitySharedMessage(
                        displayName: row.friendDisplayName,
                        activityKind: row.dive.resolvedActivityKind
                    ),
                    detail: trimmedNonEmpty(row.dive.siteName)
                )
            )

            if GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
                dive: row.dive,
                currentFirebaseUID: currentFirebaseUID
            ) {
                merged.append(
                    Item(
                        id: "activity-tag-\(row.id)",
                        kind: .buddyActivityTaggedYou(row),
                        date: activityDate(for: row.dive),
                        friendDisplayName: row.friendDisplayName,
                        friendPhotoURL: row.friendPhotoURL,
                        message: activityTaggedYouMessage(
                            displayName: row.friendDisplayName,
                            activityKind: row.dive.resolvedActivityKind
                        ),
                        detail: trimmedNonEmpty(row.dive.siteName)
                    )
                )
            }
        }

        let sorted = merged.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            let lhsRank = sortRank(for: lhs.kind)
            let rhsRank = sortRank(for: rhs.kind)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.id < rhs.id
        }
        return Array(sorted.prefix(maxItems))
    }

    nonisolated private static func sortRank(for kind: Item.Kind) -> Int {
        switch kind {
        case .buddyActivityTaggedYou: return 0
        case .buddyActivityShared: return 1
        case .friendConnected: return 2
        }
    }

    nonisolated static func friendConnectedMessage(displayName: String) -> String {
        "\(nonEmptyName(displayName)) is now your dive buddy"
    }

    nonisolated static func activitySharedMessage(
        displayName: String,
        activityKind: FriendSharedActivityKind
    ) -> String {
        let kind = activityKind == .snorkel ? "snorkel" : "dive"
        return "\(nonEmptyName(displayName)) logged a new \(kind)"
    }

    nonisolated static func activityTaggedYouMessage(
        displayName: String,
        activityKind: FriendSharedActivityKind
    ) -> String {
        let kind = activityKind == .snorkel ? "snorkel" : "dive"
        return "\(nonEmptyName(displayName)) tagged you in a new \(kind)"
    }

    /// Share/update time when present; dive start time otherwise.
    nonisolated static func activityDate(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Date {
        dive.updatedAt ?? dive.startTime ?? .distantPast
    }

    /// Bell badge — anything newer than the last time the list was opened.
    nonisolated static func hasUnread(items: [Item], lastSeenAt: Date?) -> Bool {
        guard let newest = items.first?.date else { return false }
        guard let lastSeenAt else { return true }
        return newest > lastSeenAt
    }

    nonisolated private static func nonEmptyName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "A dive buddy" : trimmed
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// Per-profile "last opened Notifications" timestamp (non-sensitive → UserDefaults).
enum HomeNotificationsLastSeenStore: Sendable {
    nonisolated static func key(ownerProfileID: UUID) -> String {
        "goDiveHomeNotificationsLastSeenAt_\(ownerProfileID.uuidString)"
    }

    nonisolated static func lastSeenAt(
        ownerProfileID: UUID,
        userDefaults: UserDefaults = .standard
    ) -> Date? {
        let key = key(ownerProfileID: ownerProfileID)
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: userDefaults.double(forKey: key))
    }

    nonisolated static func markSeen(
        ownerProfileID: UUID,
        at date: Date = Date(),
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(
            date.timeIntervalSince1970,
            forKey: key(ownerProfileID: ownerProfileID)
        )
    }
}
