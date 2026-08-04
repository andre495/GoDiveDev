import CoreGraphics
import Foundation

/// Horizontal pager between dive / snorkel overview icon tabs (large sheet body only).
///
/// Swipe left advances toward **Media**; swipe right toward **Map** — same left→right order as
/// the icon tab bars. Thresholds match **`LogbookFeedScopePagerPresentation`**.
enum DiveActivityOverviewTabPagerPresentation: Sendable {
    /// Left → right order matching **`DiveActivityIconTabBar`**.
    nonisolated static let divePages: [DiveActivityTab] = [.map, .tank, .camera]

    /// Left → right order matching **`SnorkelActivityIconTabBar`**.
    nonisolated static let snorkelPages: [SnorkelActivityTab] = [.map, .heartRate, .camera]

    nonisolated static let swipeMinimumDistance: CGFloat =
        LogbookFeedScopePagerPresentation.swipeMinimumDistance
    nonisolated static let swipeAdvanceThreshold: CGFloat =
        LogbookFeedScopePagerPresentation.swipeAdvanceThreshold

    /// **`true`** only for the resting **large** sheet while the grabber is not dragging.
    /// Header / hero area never hosts this gesture; minimized never advances tabs.
    nonisolated static func allowsHorizontalTabSwipe(
        detent: DiveActivityOverviewDetent,
        isGrabberDragging: Bool
    ) -> Bool {
        detent == .large && !isGrabberDragging
    }

    /// **`+1`** = swipe left (toward Media); **`-1`** = swipe right (toward Map).
    nonisolated static func pageStep(forHorizontalTranslation translation: CGFloat) -> Int? {
        LogbookFeedScopePagerPresentation.pageStep(forHorizontalTranslation: translation)
    }

    nonisolated static func isHorizontalSwipeDominant(
        translation: CGSize,
        minimumDistance: CGFloat = swipeMinimumDistance
    ) -> Bool {
        LogbookFeedScopePagerPresentation.isHorizontalSwipeDominant(
            translation: translation,
            minimumDistance: minimumDistance
        )
    }

    /// Next dive tab after a committed horizontal swipe, or **`nil`** at that edge / below threshold.
    nonisolated static func diveTabAfterHorizontalSwipe(
        from current: DiveActivityTab,
        translationWidth: CGFloat
    ) -> DiveActivityTab? {
        tabAfterHorizontalSwipe(from: current, pages: divePages, translationWidth: translationWidth)
    }

    /// Next snorkel tab after a committed horizontal swipe, or **`nil`** at that edge / below threshold.
    nonisolated static func snorkelTabAfterHorizontalSwipe(
        from current: SnorkelActivityTab,
        translationWidth: CGFloat
    ) -> SnorkelActivityTab? {
        tabAfterHorizontalSwipe(from: current, pages: snorkelPages, translationWidth: translationWidth)
    }

    nonisolated private static func tabAfterHorizontalSwipe<Tab: Equatable>(
        from current: Tab,
        pages: [Tab],
        translationWidth: CGFloat
    ) -> Tab? {
        guard let step = pageStep(forHorizontalTranslation: translationWidth) else { return nil }
        guard let index = pages.firstIndex(of: current) else { return nil }
        let nextIndex = index + step
        guard pages.indices.contains(nextIndex) else { return nil }
        return pages[nextIndex]
    }
}
