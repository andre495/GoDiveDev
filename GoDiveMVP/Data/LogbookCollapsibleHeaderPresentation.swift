import CoreGraphics
import Foundation
import UIKit

/// Logbook tab collapsible header copy + identifiers.
enum LogbookCollapsibleHeaderPresentation: Sendable {
    nonisolated static let title = "Activity Log"
    nonisolated static let titleAccessibilityIdentifier = "Logbook.Title"

    nonisolated static let myActivitiesSegmentTitle = "Me"
    nonisolated static let buddyFeedSegmentTitle = "Buddies"
}

/// Layout tokens for **`LogbookFeedScopeToggle`** (equal Me / Buddies segment columns).
enum LogbookFeedScopeTogglePresentation: Sendable {
    nonisolated static let segmentHeight: CGFloat = 32
    nonisolated static let segmentHorizontalPadding: CGFloat = 10
    nonisolated static let iconTitleSpacing: CGFloat = 6
    /// SF Symbol at caption.semibold is wider than the glyph point size alone.
    nonisolated static let iconGlyphWidth: CGFloat = 18
    /// Extra room so **Buddies** is not clipped at Dynamic Type / bold text.
    nonisolated static let widthSlack: CGFloat = 8
    nonisolated static let interSegmentSpacing: CGFloat = 4
    nonisolated static let shellPadding: CGFloat = 4

    /// Segmented glass shells must **not** use interactive glass — it highlights the shell
    /// without reliably delivering taps to nested plain Buttons (Me/Buddies, My Sites/All Sites,
    /// Map/Media, dive icon tabs).
    nonisolated static let shellUsesInteractiveGlass = false

    /// Equal width for both segments — sized to the longest label + icon + padding.
    nonisolated static func equalSegmentWidth(
        titles: [String] = [
            LogbookCollapsibleHeaderPresentation.myActivitiesSegmentTitle,
            LogbookCollapsibleHeaderPresentation.buddyFeedSegmentTitle,
        ]
    ) -> CGFloat {
        let base = UIFont.preferredFont(forTextStyle: .caption1)
        let font = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        let maxTextWidth = titles
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return ceil(
            iconGlyphWidth
                + iconTitleSpacing
                + maxTextWidth
                + (segmentHorizontalPadding * 2)
                + widthSlack
        )
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
            "Me"
        case .buddyFeed:
            "Buddies"
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

/// Horizontal pager between **Me** (left) and **Buddies** (right).
enum LogbookFeedScopePagerPresentation: Sendable {
    /// Left → right order matching **`LogbookFeedScopeToggle`**.
    nonisolated static let pages: [LogbookFeedScope] = [.myActivities, .buddyFeed]

    nonisolated static let accessibilityIdentifier = "Logbook.FeedScopePager"

    nonisolated static let swipeMinimumDistance: CGFloat = 12
    nonisolated static let swipeAdvanceThreshold: CGFloat = 36

    /// **`+1`** = swipe left toward **Buddies**; **`-1`** = swipe right toward **Me**.
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
