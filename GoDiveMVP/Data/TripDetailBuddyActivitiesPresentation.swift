import Foundation

/// Buddy-shared activities that fall inside a trip’s inclusive date window.
enum TripDetailBuddyActivitiesPresentation: Sendable {
    nonisolated static let emptyMessage =
        "No shared buddy activities in these trip dates yet. When GoDive buddies on this trip share dives or snorkels, they show up here."
    nonisolated static let loadingMessage = "Loading buddy activities…"

    /// Firebase UIDs for GoDive friends on the trip (planned roster + shared-trip sharer).
    nonisolated static func friendUIDsOnTrip(
        plannedBuddies: [DiveBuddy],
        sharedFromFirebaseUID: String? = nil
    ) -> [String] {
        var uids: [String] = []
        var seen = Set<String>()
        for buddy in plannedBuddies {
            guard let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) else {
                continue
            }
            if seen.insert(uid).inserted {
                uids.append(uid)
            }
        }
        if let sharer = sharedFromFirebaseUID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sharer.isEmpty,
           seen.insert(sharer).inserted {
            uids.append(sharer)
        }
        return uids
    }

    /// Keeps rows whose activity start falls on an inclusive trip calendar-day range.
    nonisolated static func rowsInTripWindow(
        _ rows: [LogbookBuddyFeedPresentation.Row],
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> [LogbookBuddyFeedPresentation.Row] {
        rows.filter { row in
            guard let startTime = row.dive.startTime else { return false }
            return DiveTripDateRange.contains(
                startTime,
                start: start,
                end: end,
                calendar: calendar
            )
        }
    }

    nonisolated static func subtitleLine(for row: LogbookBuddyFeedPresentation.Row) -> String {
        var parts: [String] = []
        if let site = row.dive.siteName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !site.isEmpty {
            parts.append(site)
        }
        if let start = row.dive.startTime {
            parts.append(
                start.formatted(
                    .dateTime.month(.abbreviated).day().year()
                )
            )
        }
        if parts.isEmpty {
            return row.dive.resolvedActivityKind == .snorkel ? "Snorkel" : "Dive"
        }
        return parts.joined(separator: " · ")
    }
}
