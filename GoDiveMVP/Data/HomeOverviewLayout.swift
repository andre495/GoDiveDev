import CoreGraphics
import Foundation

/// Carousel height for the Home hero; stats fill remaining viewport down to the tab bar.
enum HomeOverviewLayout: Sendable {

    /// Breathing room above tab-bar content inside the stats panel.
    nonisolated static let tabBarScrollInset: CGFloat = 16

    /// Kept in sync with **`HomeLifetimeStatsLayout.panelOverlap`**.
    nonisolated static let panelOverlap: CGFloat = 148

    nonisolated static let heroHeightToWidthRatio: CGFloat = 0.77

    /// Kept in sync with **`HomeLifetimeStatsLayout.heroBottomExtension`**.
    nonisolated static let heroBottomExtension: CGFloat = 162

    nonisolated static func heroHeight(
        width: CGFloat,
        topSafeAreaInset: CGFloat,
        additionalBottomExtension: CGFloat? = nil
    ) -> CGFloat {
        let extensionHeight = additionalBottomExtension ?? 162
        return max(width * 0.77 + topSafeAreaInset + extensionHeight, 1)
    }

    struct Metrics: Sendable, Equatable {
        /// Fixed height for the media block (edge-to-edge at the top).
        let heroHeight: CGFloat
    }

    /// **`viewportHeight`** — full Home tab content height from **`GeometryReader`**.
    nonisolated static func metrics(
        viewportHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat
    ) -> Metrics {
        let tabInset: CGFloat = 16
        let overlap: CGFloat = 148
        let heroRatio: CGFloat = 0.77
        let heroExtension: CGFloat = 162

        let naturalCarouselHeight = max(screenWidth * heroRatio + topSafeAreaInset + heroExtension, 1)
        let minimumStatsBand = statsPanelContentHeight + tabInset
        let maximumCarouselHeight = max(viewportHeight - minimumStatsBand + overlap, 1)
        let carouselHeight = min(naturalCarouselHeight, maximumCarouselHeight)

        return Metrics(heroHeight: carouselHeight)
    }
}
