import CoreGraphics
import Foundation

/// Home tab-root geometry normalization — same full-screen coordinate space as pushed detail pages.
///
/// Tab content **`GeometryReader`** height (~803pt) sits above the root tab bar. Detail pages use full-screen
/// geometry (~852pt) with the tab bar hidden. Home layout math uses **virtual full-screen height** so hero +
/// blue sheet proportions match **`BlueSheetDetailPage`** exactly.
enum HomeTabRootLayoutPresentation: Sendable {

    nonisolated static func tabContentGeometryHeight(
        geometryHeight: CGFloat,
        isNavigationStackAtRoot: Bool,
        frozenTabContentGeometryHeight: CGFloat?
    ) -> CGFloat {
        if isNavigationStackAtRoot {
            return HomeOverviewLayout.settledHomeTabContentGeometryHeight(from: geometryHeight)
        }
        if let frozenTabContentGeometryHeight, frozenTabContentGeometryHeight > 0 {
            return frozenTabContentGeometryHeight
        }
        return HomeOverviewLayout.settledHomeTabContentGeometryHeight(from: geometryHeight)
    }

    /// Full-screen height detail pages use when the root tab bar is hidden.
    nonisolated static func referenceFullScreenGeometryHeight(from tabContentGeometryHeight: CGFloat) -> CGFloat {
        HomeOverviewLayout.tabRootVirtualFullScreenHeight(from: tabContentGeometryHeight)
    }

    /// Hero viewport band — same subtraction detail pages apply to full-screen geometry.
    nonisolated static func referenceHeroLayoutViewportHeight(from tabContentGeometryHeight: CGFloat) -> CGFloat {
        HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: referenceFullScreenGeometryHeight(from: tabContentGeometryHeight)
        )
    }

    /// Detail-style **`VStack`** frame — virtual full screen; panel bottom inset clears the root tab bar.
    nonisolated static func stackFrameHeight(from tabContentGeometryHeight: CGFloat) -> CGFloat {
        HomeOverviewLayout.pushedPageLayoutHeight(
            from: referenceFullScreenGeometryHeight(from: tabContentGeometryHeight)
        )
    }

    /// Bottom content inset for the stats panel — prefers live **`UITabBar`** geometry.
    nonisolated static func panelBottomSafeAreaInset(
        measuredTabBarClearance: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        RootTabBarLayoutMeasurement.resolvedPanelBottomSafeAreaInset(
            measuredTabBarClearance: measuredTabBarClearance,
            safeAreaBottom: safeAreaBottom
        )
    }

    /// Blue sheet seam inputs for **`LogOverviewView`** — keep empty and populated roots on the same band math.
    nonisolated static func seamInputs(
        showsBuddyLeaderboard: Bool
    ) -> HomeOverviewPushedLayoutPresentation.SeamInputs {
        HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeLifetimeStatsLayout.estimatedPanelContentHeight(
                showsBuddyLeaderboard: showsBuddyLeaderboard
            ),
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    /// Default Home stats band (2×2 lifetime grid + **Top buddies**).
    nonisolated static var defaultLifetimeGridSeamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs {
        seamInputs(showsBuddyLeaderboard: true)
    }
}
