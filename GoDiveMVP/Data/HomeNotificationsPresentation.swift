import Foundation

/// Home bell → **Notifications** list. Items derive from Firestore social data
/// (friendship `since` dates + friend-shared activities + likes/comments on your shares),
/// so the list matches what pushes announced even when a push was never delivered.
enum HomeNotificationsPresentation: Sendable {
    nonisolated static let pageTitle = "Notifications"
    nonisolated static let maxItems = 100
    nonisolated static let emptyStateMessage =
        "No notifications yet. When buddies connect, share activities, like and comment on your posts, or mention you, they show up here."
    nonisolated static let newSectionTitle = "New"
    nonisolated static let olderSectionTitle = "Older"
    nonisolated static let noNewNotificationsMessage = "You have no new notifications"
    /// Age cutoff paired with unread for the **New** section.
    nonisolated static let newSectionRecency: TimeInterval = 14 * 24 * 60 * 60
    nonisolated static let bellAccessibilityIdentifier = "Home.NotificationsBell"

    /// **New** vs **Older** buckets for the Notifications list (newest-first within each).
    struct Sections: Equatable, Sendable {
        var newItems: [Item]
        var older: [Item]
    }

    /// Tap target for likes / comments on the signed-in user's own shared activity.
    struct OwnedActivityTarget: Equatable, Sendable, Hashable {
        var activityID: UUID
        var activityKind: FriendSharedActivityKind
        var opensComments: Bool
    }

    /// Tap target for `@mention` in a comment (owned activity or friend-shared feed row).
    struct MentionTarget: Equatable, Sendable, Hashable {
        enum Destination: Equatable, Sendable, Hashable {
            case owned(OwnedActivityTarget)
            case shared(LogbookBuddyFeedPresentation.Row)
        }

        var destination: Destination
    }

    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case friendConnected(GoDiveFriendGraphService.FriendEdge)
            case buddyActivityShared(LogbookBuddyFeedPresentation.Row)
            case buddyActivityTaggedYou(LogbookBuddyFeedPresentation.Row)
            case buddyActivityLiked(OwnedActivityTarget)
            case buddyActivityCommented(OwnedActivityTarget)
            case buddyActivityMentioned(MentionTarget)
        }

        var id: String
        var kind: Kind
        var date: Date
        var friendDisplayName: String
        var friendPhotoURL: String?
        var message: String
        /// Secondary line (site name for activities; comment preview when present).
        var detail: String?
    }

    /// Merged newest-first notification items from the buddy feed snapshot + owned social events.
    nonisolated static func items(
        friends: [GoDiveFriendGraphService.FriendEdge],
        activityRows: [LogbookBuddyFeedPresentation.Row],
        ownedSocialEvents: [HomeNotificationsOwnedSocialSync.Event] = [],
        mentionEvents: [HomeNotificationsMentionSync.Event] = [],
        currentFirebaseUID: String? = nil
    ) -> [Item] {
        var merged: [Item] = []
        merged.reserveCapacity(
            friends.count + activityRows.count * 2 + ownedSocialEvents.count + mentionEvents.count
        )

        let photoURLByUID = friendPhotoURLByUID(friends)

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

        for event in ownedSocialEvents {
            merged.append(item(from: event, photoURLByUID: photoURLByUID))
        }

        for event in mentionEvents {
            if let mentionItem = item(from: event, photoURLByUID: photoURLByUID) {
                merged.append(mentionItem)
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

    nonisolated static func item(
        from event: HomeNotificationsOwnedSocialSync.Event,
        photoURLByUID: [String: String]
    ) -> Item {
        let photoURL = photoURLByUID[event.actorUID]
        switch event.kind {
        case .like:
            return Item(
                id: event.id,
                kind: .buddyActivityLiked(
                    OwnedActivityTarget(
                        activityID: event.activityID,
                        activityKind: event.activityKind,
                        opensComments: false
                    )
                ),
                date: event.createdAt,
                friendDisplayName: event.actorDisplayName,
                friendPhotoURL: photoURL,
                message: activityLikedMessage(
                    displayName: event.actorDisplayName,
                    activityKind: event.activityKind
                ),
                detail: trimmedNonEmpty(event.siteName)
            )
        case .comment:
            return Item(
                id: event.id,
                kind: .buddyActivityCommented(
                    OwnedActivityTarget(
                        activityID: event.activityID,
                        activityKind: event.activityKind,
                        opensComments: true
                    )
                ),
                date: event.createdAt,
                friendDisplayName: event.actorDisplayName,
                friendPhotoURL: photoURL,
                message: activityCommentedMessage(
                    displayName: event.actorDisplayName,
                    activityKind: event.activityKind,
                    commentText: event.commentText
                ),
                /// Prefer the comment snippet in the secondary line (site name only as fallback).
                detail: commentedNotificationDetail(
                    commentText: event.commentText,
                    siteName: event.siteName
                )
            )
        case .mention:
            return Item(
                id: event.id,
                kind: .buddyActivityMentioned(
                    MentionTarget(
                        destination: .owned(
                            OwnedActivityTarget(
                                activityID: event.activityID,
                                activityKind: event.activityKind,
                                opensComments: true
                            )
                        )
                    )
                ),
                date: event.createdAt,
                friendDisplayName: event.actorDisplayName,
                friendPhotoURL: photoURL,
                message: activityMentionedMessage(displayName: event.actorDisplayName),
                detail: commentedNotificationDetail(
                    commentText: event.commentText,
                    siteName: event.siteName
                )
            )
        }
    }

    nonisolated static func item(
        from event: HomeNotificationsMentionSync.Event,
        photoURLByUID: [String: String]
    ) -> Item? {
        guard let row = event.feedRow else { return nil }
        let photoURL = photoURLByUID[event.actorUID] ?? row.friendPhotoURL
        return Item(
            id: event.id,
            kind: .buddyActivityMentioned(MentionTarget(destination: .shared(row))),
            date: event.createdAt,
            friendDisplayName: event.actorDisplayName,
            friendPhotoURL: photoURL,
            message: activityMentionedMessage(displayName: event.actorDisplayName),
            detail: commentedNotificationDetail(
                commentText: event.commentText,
                siteName: event.siteName
            )
        )
    }

    /// Secondary line for comment rows — comment preview when present, else site name.
    nonisolated static func commentedNotificationDetail(
        commentText: String?,
        siteName: String?
    ) -> String? {
        if let preview = GoDiveBuddyActivityCommentedPushPresentation.commentNotificationPreview(
            commentText
        ) {
            return preview
        }
        return trimmedNonEmpty(siteName)
    }

    nonisolated static func friendPhotoURLByUID(
        _ friends: [GoDiveFriendGraphService.FriendEdge]
    ) -> [String: String] {
        var map: [String: String] = [:]
        for friend in friends {
            let uid = friend.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = friend.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !uid.isEmpty, !url.isEmpty else { continue }
            map[uid] = url
        }
        return map
    }

    nonisolated private static func sortRank(for kind: Item.Kind) -> Int {
        switch kind {
        case .buddyActivityMentioned: return 0
        case .buddyActivityCommented: return 1
        case .buddyActivityLiked: return 2
        case .buddyActivityTaggedYou: return 3
        case .buddyActivityShared: return 4
        case .friendConnected: return 5
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

    nonisolated static func activityLikedMessage(
        displayName: String,
        activityKind: FriendSharedActivityKind
    ) -> String {
        GoDiveBuddyActivityLikedPushPresentation.notificationBody(
            likerDisplayName: displayName,
            activityKind: activityKind
        )
    }

    nonisolated static func activityCommentedMessage(
        displayName: String,
        activityKind: FriendSharedActivityKind,
        commentText: String? = nil
    ) -> String {
        let kind = activityKind == .snorkel ? "snorkel" : "dive"
        let base = "\(nonEmptyName(displayName)) commented on your \(kind)"
        if let preview = GoDiveBuddyActivityCommentedPushPresentation.commentNotificationPreview(
            commentText
        ) {
            return "\(base): \(preview)"
        }
        return base
    }

    nonisolated static func activityMentionedMessage(displayName: String) -> String {
        "\(nonEmptyName(displayName)) mentioned you in a comment"
    }

    /// First-share time when present; otherwise last projection update; else dive start.
    /// Prefer **`sharedAt`** so media/republish bumps to **`updatedAt`** do not flood the list.
    nonisolated static func activityDate(
        for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> Date {
        dive.sharedAt ?? dive.updatedAt ?? dive.startTime ?? .distantPast
    }

    /// Bell badge — anything newer than the last time the list was opened.
    nonisolated static func hasUnread(items: [Item], lastSeenAt: Date?) -> Bool {
        guard let newest = items.first?.date else { return false }
        guard let lastSeenAt else { return true }
        return newest > lastSeenAt
    }

    /// Per-row unread — same watermark as the bell (`nil` last-seen → all unread).
    nonisolated static func isUnread(itemDate: Date, lastSeenAt: Date?) -> Bool {
        guard let lastSeenAt else { return true }
        return itemDate > lastSeenAt
    }

    /// Item date is within the last 2 weeks.
    nonisolated static func isWithinNewSectionRecency(
        itemDate: Date,
        now: Date = Date()
    ) -> Bool {
        itemDate > now.addingTimeInterval(-newSectionRecency)
    }

    /// **New** = unread **and** less than 2 weeks old.
    /// **Older** = everything else (including all items older than 2 weeks, read or unread).
    nonisolated static func belongsInNewSection(
        itemDate: Date,
        lastSeenAt: Date?,
        now: Date = Date()
    ) -> Bool {
        isUnread(itemDate: itemDate, lastSeenAt: lastSeenAt)
            && isWithinNewSectionRecency(itemDate: itemDate, now: now)
    }

    /// Split a newest-first list into **New** / **Older**.
    nonisolated static func sections(
        items: [Item],
        lastSeenAt: Date?,
        now: Date = Date()
    ) -> Sections {
        var newItems: [Item] = []
        var older: [Item] = []
        newItems.reserveCapacity(items.count)
        older.reserveCapacity(items.count)
        for item in items {
            if belongsInNewSection(
                itemDate: item.date,
                lastSeenAt: lastSeenAt,
                now: now
            ) {
                newItems.append(item)
            } else {
                older.append(item)
            }
        }
        return Sections(newItems: newItems, older: older)
    }

    /// Read rows stay tappable but visually quieter than unread.
    nonisolated static let readRowOpacity: Double = 0.48
    nonisolated static let unreadRowOpacity: Double = 1

    nonisolated static func rowOpacity(isUnread: Bool) -> Double {
        isUnread ? unreadRowOpacity : readRowOpacity
    }

    /// Unread titles use semibold; read titles use regular.
    nonisolated static func usesSemiboldTitle(isUnread: Bool) -> Bool {
        isUnread
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
