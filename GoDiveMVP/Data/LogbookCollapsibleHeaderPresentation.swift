import Foundation

/// Logbook tab collapsible header copy + identifiers.
enum LogbookCollapsibleHeaderPresentation: Sendable {
    nonisolated static let title = "Activity Log"
    nonisolated static let titleAccessibilityIdentifier = "Logbook.Title"
    nonisolated static let myActivitiesSummaryAccessibilityIdentifier = "Logbook.MyActivitiesSummary"

    nonisolated static let myActivitiesSegmentTitle = "My Activities"
    nonisolated static let buddyFeedSegmentTitle = "Buddy Feed"

    nonisolated static func showsMyActivitiesSummaryChrome(
        feedScope: LogbookFeedScope,
        showsStoredDiveEmptyState: Bool
    ) -> Bool {
        feedScope == .myActivities && !showsStoredDiveEmptyState
    }
}

/// Activity Log list scope — own dives vs friends’ shared projections.
enum LogbookFeedScope: String, CaseIterable, Identifiable, Sendable {
    case myActivities
    case buddyFeed

    var id: String { rawValue }

    var segmentTitle: String {
        switch self {
        case .myActivities:
            LogbookCollapsibleHeaderPresentation.myActivitiesSegmentTitle
        case .buddyFeed:
            LogbookCollapsibleHeaderPresentation.buddyFeedSegmentTitle
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .myActivities:
            "My activities"
        case .buddyFeed:
            "Buddy feed"
        }
    }

    var systemImage: String {
        switch self {
        case .myActivities:
            "book.closed.fill"
        case .buddyFeed:
            "person.2.fill"
        }
    }
}
