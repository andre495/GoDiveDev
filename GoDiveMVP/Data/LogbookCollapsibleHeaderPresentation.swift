import CoreGraphics
import Foundation

/// Logbook tab collapsible header copy + identifiers.
enum LogbookCollapsibleHeaderPresentation: Sendable {
    nonisolated static let title = "Activity Log"
    nonisolated static let titleAccessibilityIdentifier = "Logbook.Title"

    nonisolated static let myActivitiesSegmentTitle = "My Activities"
    nonisolated static let buddyFeedSegmentTitle = "Buddy Feed"
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

/// Horizontal pager between **My Activities** (left) and **Buddy Feed** (right).
enum LogbookFeedScopePagerPresentation: Sendable {
    /// Left → right order matching **`LogbookFeedScopeToggle`**.
    nonisolated static let pages: [LogbookFeedScope] = [.myActivities, .buddyFeed]

    nonisolated static let accessibilityIdentifier = "Logbook.FeedScopePager"

    nonisolated static let swipeMinimumDistance: CGFloat = 12
    nonisolated static let swipeAdvanceThreshold: CGFloat = 36

    /// **`+1`** = swipe left toward **Buddy Feed**; **`-1`** = swipe right toward **My Activities**.
    nonisolated static func pageStep(forHorizontalTranslation translation: CGFloat) -> Int? {
        guard abs(translation) >= swipeAdvanceThreshold else { return nil }
        if translation < 0 { return 1 }
        if translation > 0 { return -1 }
        return nil
    }

    /// Next scope after a committed horizontal swipe, or **`nil`** when already at that edge / below threshold.
    nonisolated static func scopeAfterHorizontalSwipe(
        from current: LogbookFeedScope,
        translationWidth: CGFloat
    ) -> LogbookFeedScope? {
        guard let step = pageStep(forHorizontalTranslation: translationWidth) else { return nil }
        guard let index = pages.firstIndex(of: current) else { return nil }
        let nextIndex = index + step
        guard pages.indices.contains(nextIndex) else { return nil }
        return pages[nextIndex]
    }

    nonisolated static func isHorizontalSwipeDominant(
        translation: CGSize,
        minimumDistance: CGFloat = swipeMinimumDistance
    ) -> Bool {
        let width = abs(translation.width)
        let height = abs(translation.height)
        guard max(width, height) >= minimumDistance else { return false }
        return width > height
    }
}
