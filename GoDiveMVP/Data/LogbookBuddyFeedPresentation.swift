import Foundation

/// Logbook **Buddy Feed** — merged friend-visible dive projections for the Activity Log tab.
enum LogbookBuddyFeedPresentation: Sendable {
    struct Row: Equatable, Sendable, Identifiable {
        var id: String
        var friendUID: String
        var friendDisplayName: String
        var dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    }

    enum EmptyKind: Equatable, Sendable {
        case noFriends
        case noSharedDives
        case unavailable
    }

    nonisolated static let scopePickerAccessibilityIdentifier = "Logbook.FeedScopePicker"
    nonisolated static let buddyFeedRootAccessibilityIdentifier = "Logbook.BuddyFeed.Root"

    nonisolated static let noFriendsTitle = "No friends yet"
    nonisolated static let noFriendsMessage =
        "When friends share dives with you, their activities show up here. Invite someone to get started."

    nonisolated static let noActivitiesTitle = "No buddy activities yet"
    nonisolated static let noActivitiesMessage =
        "None of your friends have shared dives yet. Check back later, or invite more divers from Friends."

    nonisolated static let unavailableTitle = "Can't load buddy feed"

    nonisolated static let addFriendsButtonTitle = "Add friends"
    nonisolated static let viewFriendsButtonTitle = "View friends"
    nonisolated static let openFriendsButtonAccessibilityIdentifier = "Logbook.BuddyFeed.OpenFriends"

    nonisolated static func openFriendsButtonTitle(for kind: EmptyKind) -> String? {
        switch kind {
        case .noFriends:
            addFriendsButtonTitle
        case .noSharedDives:
            viewFriendsButtonTitle
        case .unavailable:
            nil
        }
    }

    nonisolated static func showsOpenFriendsButton(for kind: EmptyKind) -> Bool {
        openFriendsButtonTitle(for: kind) != nil
    }

    nonisolated static func rowsEqual(_ lhs: [Row], _ rhs: [Row]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            let left = lhs[index]
            let right = rhs[index]
            if left.id != right.id
                || left.friendUID != right.friendUID
                || left.friendDisplayName != right.friendDisplayName
                || left.dive.id != right.dive.id
            {
                return false
            }
        }
        return true
    }

    nonisolated static func emptyKindsEqual(_ lhs: EmptyKind?, _ rhs: EmptyKind?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.noFriends?, .noFriends?),
             (.noSharedDives?, .noSharedDives?),
             (.unavailable?, .unavailable?):
            return true
        default:
            return false
        }
    }

    nonisolated static func rowID(friendUID: String, diveDocumentID: String) -> String {
        "\(friendUID)_\(diveDocumentID)"
    }

    nonisolated static func rows(
        friends: [GoDiveFriendGraphService.FriendEdge],
        divesByFriendUID: [String: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]]
    ) -> [Row] {
        var merged: [Row] = []
        merged.reserveCapacity(divesByFriendUID.values.reduce(0) { $0 + $1.count })
        for friend in friends {
            let dives = divesByFriendUID[friend.friendUID] ?? []
            for dive in dives {
                merged.append(
                    Row(
                        id: rowID(friendUID: friend.friendUID, diveDocumentID: dive.id),
                        friendUID: friend.friendUID,
                        friendDisplayName: friend.displayName,
                        dive: dive
                    )
                )
            }
        }
        return sortRowsNewestFirst(merged)
    }

    nonisolated static func sortRowsNewestFirst(_ rows: [Row]) -> [Row] {
        rows.sorted { lhs, rhs in
            let left = lhs.dive.startTime ?? .distantPast
            let right = rhs.dive.startTime ?? .distantPast
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func subtitle(for dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> String {
        var parts: [String] = []
        if let number = dive.diveNumber {
            parts.append("#\(number)")
        }
        if let start = dive.startTime {
            parts.append(start.formatted(date: .abbreviated, time: .omitted))
        }
        if let max = dive.maxDepthMeters {
            parts.append(String(format: "%.0f m", max))
        }
        if let minutes = dive.durationMinutes {
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }

    nonisolated static func emptyKind(
        friends: [GoDiveFriendGraphService.FriendEdge],
        rows: [Row],
        firebaseConfigured: Bool,
        isSignedIn: Bool
    ) -> EmptyKind? {
        guard firebaseConfigured, isSignedIn else { return .unavailable }
        if friends.isEmpty { return .noFriends }
        if rows.isEmpty { return .noSharedDives }
        return nil
    }

    /// Buddy Feed auto-refresh when the list is visible (logbook stack at root + **Buddy Feed** segment + Logbook tab selected).
    nonisolated static func shouldAutoRefreshBuddyFeedList(
        feedScope: LogbookFeedScope,
        navigationPathCount: Int,
        isLogbookTabSelected: Bool
    ) -> Bool {
        isLogbookTabSelected
            && feedScope == .buddyFeed
            && navigationPathCount == 0
    }
}
