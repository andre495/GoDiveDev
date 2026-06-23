import CoreGraphics
import Foundation

/// Carousel height for the Home hero; stats fill remaining viewport down to the tab bar.
enum HomeOverviewLayout: Sendable {

    /// Breathing room above tab-bar content inside the stats panel.
    nonisolated static let tabBarScrollInset: CGFloat = 16

    /// Root tab bar layout height when pushed flows hide it — **`GeometryReader`** is taller than Home tab content.
    nonisolated static let rootTabBarLayoutHeight: CGFloat = 49

    /// Match Home tab **`GeometryReader`** height on pushed pages (**`hidesBottomTabBarWhenPushed()`**).
    nonisolated static func viewportHeightMatchingHomeTab(from geometryHeight: CGFloat) -> CGFloat {
        max(geometryHeight - rootTabBarLayoutHeight, 1)
    }

    /// Home root viewport for hero + stats layout. While **`NavigationStack`** is pushed, the tab bar is hidden and **`GeometryReader`** is taller; subtract tab bar height so interactive pop peek-through matches settled root layout.
    nonisolated static func homeRootViewportHeight(
        geometryHeight: CGFloat,
        isNavigationStackAtRoot: Bool
    ) -> CGFloat {
        isNavigationStackAtRoot
            ? geometryHeight
            : viewportHeightMatchingHomeTab(from: geometryHeight)
    }

    /// Stats band for hero/sheet overlap seam — matches **`LogOverviewView`** with the 2×2 lifetime grid (same minimum band Home uses when **Top buddies** is hidden).
    nonisolated static let heroLayoutStatsPanelContentHeight: CGFloat =
        HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)

    /// Stats band when Home shows **Top buddies** — tighter **`maximumCarouselHeight`** cap on wide phones.
    nonisolated static let heroLayoutStatsPanelContentHeightWithLeaderboard: CGFloat =
        HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)

    /// Same stats-band height **`LogOverviewView`** uses for hero/sheet seam math.
    nonisolated static func statsPanelContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }

    /// Hero metrics for pushed buddy/trip pages — viewport subtracts **`rootTabBarLayoutHeight`** so the seam matches settled Home tab content (**`LogOverviewView`** at stack root).
    ///
    /// Pass the same **`statsPanelContentHeight`** Home uses (**`HomeOverviewPushedLayoutPresentation.seamInputs`**) so **`sheet.seamYFromScreenBottom`** / **`screenBot`** match from the physical screen edge.
    ///
    /// When **`showsBuddyLeaderboard`** is **`true`**, caps hero height with the **Top buddies** stats band on wide phones (same constraint as **`LogOverviewView`**).
    ///
    /// Pass **`transitionViewportFloor`** from the pushed page when the first **`GeometryReader`** pass reports Home tab content height (803) before the root tab bar hides (852).
    nonisolated static func pushedHeroLayoutMetrics(
        geometryHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat = heroLayoutStatsPanelContentHeight,
        showsBuddyLeaderboard: Bool = false,
        transitionViewportFloor: CGFloat = 0
    ) -> Metrics {
        if let anchoredHero = HomeOverviewLayoutAnchor.matchingRootHeroHeight(
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset
        ) {
            return Metrics(heroHeight: anchoredHero)
        }

        let homeTabViewport = pushedHeroLayoutViewportHeight(
            from: geometryHeight,
            transitionViewportFloor: transitionViewportFloor
        )
        let primaryMetrics = metrics(
            viewportHeight: homeTabViewport,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsPanelContentHeight
        )
        guard showsBuddyLeaderboard else { return primaryMetrics }
        let leaderboardCapMetrics = metrics(
            viewportHeight: homeTabViewport,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: heroLayoutStatsPanelContentHeightWithLeaderboard
        )
        return Metrics(
            heroHeight: min(primaryMetrics.heroHeight, leaderboardCapMetrics.heroHeight)
        )
    }

    /// Safe top for pushed hero seam math — same raw **`GeometryReader`** input as **`LogOverviewView.homeOverviewLayoutMetrics`**, with an optional floor during push transition.
    nonisolated static func pushedHeroTopSafeAreaInset(
        rawGeometrySafeTop: CGFloat,
        transitionSafeTopFloor: CGFloat = 0
    ) -> CGFloat {
        max(rawGeometrySafeTop, transitionSafeTopFloor)
    }

    /// **`sheet.seamYFromScreenBottom`** / overlay **`screenBot`** — physical screen bottom up to the sheet seam.
    nonisolated static func sheetSeamYFromScreenBottom(
        pageKind: PageLayoutKind,
        geometryHeight: CGFloat,
        heroHeight: CGFloat,
        showsHeroOverlap: Bool = true
    ) -> CGFloat {
        let overlap = showsHeroOverlap ? panelOverlap : 0
        let seamY = max(heroHeight - overlap, 0)
        let tabBarBelowGeometry = pageKind == .home ? rootTabBarLayoutHeight : 0
        return max(geometryHeight + tabBarBelowGeometry - seamY, 0)
    }

    /// Native **`TabView`** page-dot clearance above the home indicator on pushed hero + sheet pages.
    nonisolated static let pageIndicatorClearance: CGFloat = 28

    /// Scroll bottom inset for buddy/trip pagers — home indicator + page dots.
    nonisolated static func pushedPageScrollBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        safeAreaBottom + pageIndicatorClearance
    }

    /// Bottom material band — same height as root tab bar + home indicator (logbook **`goDiveRootTabBarChrome()`**).
    nonisolated static func pushedPanelBottomScrollFadeHeight(safeAreaBottom: CGFloat) -> CGFloat {
        rootTabBarLayoutHeight + safeAreaBottom
    }

    /// Pushed **`GeometryReader`** height minus root tab bar — same vertical band as Home tab content above the main menu.
    nonisolated static func settledHomeTabLayoutViewportHeight(from geometryHeight: CGFloat) -> CGFloat {
        viewportHeightMatchingHomeTab(from: geometryHeight)
    }

    /// First pushed **`GeometryReader`** pass may report Home tab content height before the root tab bar hides. Latch this candidate across frames so the floor survives full-screen geometry.
    nonisolated static func pushedHeroLayoutTransitionViewportCandidate(from geometryHeight: CGFloat) -> CGFloat {
        min(
            geometryHeight,
            settledHomeTabLayoutViewportHeight(from: geometryHeight + rootTabBarLayoutHeight)
        )
    }

    /// Stable Home tab viewport for pushed hero + sheet layout.
    ///
    /// Settled full-screen geometry (852) subtracts the hidden tab bar (803). **`transitionViewportFloor`**
    /// is only honored when it preserves the tab-content band — never when it inflates past
    /// **`viewportHeightMatchingHomeTab`** (a latched 852 floor was dropping **`screenBot`** ~90pt).
    nonisolated static func pushedHeroLayoutViewportHeight(
        from geometryHeight: CGFloat,
        transitionViewportFloor: CGFloat = 0
    ) -> CGFloat {
        let homeTabViewport = viewportHeightMatchingHomeTab(from: geometryHeight)
        guard transitionViewportFloor > 0,
              transitionViewportFloor <= homeTabViewport + rootTabBarLayoutHeight - 1 else {
            return homeTabViewport
        }
        return max(homeTabViewport, transitionViewportFloor)
    }

    /// Hero + sheet **`VStack`** frame — full pushed **`GeometryReader`** height so the blue sheet reaches the screen bottom.
    ///
    /// Hero height still uses **`pushedHeroLayoutViewportHeight`** (Home tab band) so **`sheet.seamYFromScreenBottom`** matches **`LogOverviewView`**.
    nonisolated static func pushedPageLayoutHeight(
        from geometryHeight: CGFloat,
        transitionViewportFloor: CGFloat = 0
    ) -> CGFloat {
        _ = transitionViewportFloor
        return max(geometryHeight, 1)
    }

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
        let overlap: CGFloat = panelOverlap
        let heroRatio: CGFloat = heroHeightToWidthRatio
        let heroExtension: CGFloat = heroBottomExtension

        let naturalCarouselHeight = max(screenWidth * heroRatio + topSafeAreaInset + heroExtension, 1)
        let minimumStatsBand = statsPanelContentHeight + tabBarScrollInset
        let maximumCarouselHeight = max(viewportHeight - minimumStatsBand + overlap, 1)
        let carouselHeight = min(naturalCarouselHeight, maximumCarouselHeight)

        return Metrics(heroHeight: carouselHeight)
    }
}
