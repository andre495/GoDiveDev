import Foundation
import SwiftData

/// Unified **Profile → Buddies** list — local roster + GoDive friends in one sort order.
enum BuddiesListPresentation: Sendable {
    nonisolated static let pageTitle = "Buddies"
    nonisolated static let emptyTitle = "No buddies yet"
    nonisolated static let emptyMessage =
        "Tap + to add a dive buddy, or invite someone with the QR button. Connected GoDive friends appear here too."
    nonisolated static let inviteButtonTitle = "Invite"
    nonisolated static let inviteAccessibilityLabel = "Invite to GoDive"
    nonisolated static let friendBadgeAccessibilityLabel = "GoDive friend"

    nonisolated static func friendTotalDivesLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "0 total dives"
        case 1:
            return "1 total dive"
        default:
            return "\(count) total dives"
        }
    }

    nonisolated static func smsBody(inviteURL: URL, buddyDisplayName: String) -> String {
        let name = buddyDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Connect with me on GoDive: \(inviteURL.absoluteString)"
        }
        return "Hey \(name) — connect with me on GoDive: \(inviteURL.absoluteString)"
    }

    /// Merges roster buddies with friend edges that have no linked roster row yet.
    nonisolated static func mergedRows(
        friends: [GoDiveFriendGraphService.FriendEdge],
        rosterBuddies: [DiveBuddy],
        sharedDiveCount: (DiveBuddy) -> Int
    ) -> [BuddiesListRow] {
        let friendsByUID = Dictionary(uniqueKeysWithValues: friends.map { ($0.friendUID, $0) })
        var consumedFriendUIDs = Set<String>()
        var sortableRows: [(name: String, row: BuddiesListRow)] = []

        for buddy in rosterBuddies {
            let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
            let edge: GoDiveFriendGraphService.FriendEdge?
            if let uid {
                edge = friendsByUID[uid] ?? DiveBuddyFriendLinkPresentation.friendEdge(for: buddy)
                consumedFriendUIDs.insert(uid)
            } else {
                edge = nil
            }
            sortableRows.append(
                (
                    name: buddy.displayName,
                    row: BuddiesListRow(
                    id: "buddy-\(buddy.id.uuidString)",
                    displayName: buddy.displayName,
                    buddy: buddy,
                    friendEdge: edge,
                    sharedDiveCount: sharedDiveCount(buddy),
                    friendTotalDiveCount: edge?.totalDiveCount
                )
                )
            )
        }

        for friend in friends where !consumedFriendUIDs.contains(friend.friendUID) {
            sortableRows.append(
                (
                    name: friend.displayName,
                    row: BuddiesListRow(
                    id: "friend-\(friend.friendUID)",
                    displayName: friend.displayName,
                    buddy: nil,
                    friendEdge: friend,
                    sharedDiveCount: 0,
                    friendTotalDiveCount: friend.totalDiveCount
                )
                )
            )
        }

        return sortableRows
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(\.row)
    }
}

struct BuddiesListRow: Identifiable {
    let id: String
    let displayName: String
    let buddy: DiveBuddy?
    let friendEdge: GoDiveFriendGraphService.FriendEdge?
    let sharedDiveCount: Int
    let friendTotalDiveCount: Int?

    var sortKey: String { displayName }

    var isFriend: Bool { friendEdge != nil }

    var divesTogetherSubtitle: String {
        DiveBuddyRosterPresentation.sharedDiveCountLabel(sharedDiveCount)
    }

    var subtitle: String {
        if isFriend {
            if let friendTotalDiveCount {
                return "\(BuddiesListPresentation.friendTotalDivesLabel(friendTotalDiveCount)), \(divesTogetherSubtitle)"
            }
            return divesTogetherSubtitle
        }
        if buddy != nil {
            return divesTogetherSubtitle
        }
        return ""
    }

    /// Value-based push — avoids eager **`NavigationLink { destination }`** building every row’s detail view.
    var navigationRoute: BuddiesListNavigationRoute? {
        if let friendEdge {
            return .friend(friendEdge)
        }
        if let buddy {
            return .rosterBuddy(buddy.id)
        }
        return nil
    }
}

enum BuddiesListNavigationRoute: Hashable {
    case friend(GoDiveFriendGraphService.FriendEdge)
    case rosterBuddy(UUID)
}
