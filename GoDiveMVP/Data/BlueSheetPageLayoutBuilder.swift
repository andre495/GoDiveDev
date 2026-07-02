import CoreGraphics
import SwiftUI

/// Shared hero vs blue-sheet proportion tokens — single source for Home tab root and pushed detail pages.
enum BlueSheetPageProportions: Sendable {
    nonisolated static var panelOverlap: CGFloat { HomeOverviewLayout.panelOverlap }
    nonisolated static var blueSheetPanelScale: CGFloat { HomeOverviewLayout.blueSheetPanelScale }
    nonisolated static func minimumStatsBandHeight(statsPanelContentHeight: CGFloat) -> CGFloat {
        HomeOverviewLayout.minimumStatsBandHeight(statsPanelContentHeight: statsPanelContentHeight)
    }
    nonisolated static var heroHeightToWidthRatio: CGFloat { HomeOverviewLayout.heroHeightToWidthRatio }
    nonisolated static var heroBottomExtension: CGFloat { HomeOverviewLayout.heroBottomExtension }
    nonisolated static var tabBarScrollInset: CGFloat { HomeOverviewLayout.tabBarScrollInset }
    nonisolated static var rootTabBarLayoutHeight: CGFloat { HomeOverviewLayout.rootTabBarLayoutHeight }
    nonisolated static var pageIndicatorClearance: CGFloat { HomeOverviewLayout.pageIndicatorClearance }
}

/// How viewport + hero height are resolved for tab root vs pushed detail shells.
enum BlueSheetPageLayoutMode: Sendable, Equatable {
    case tabRoot(isNavigationStackAtRoot: Bool, frozenRootViewportHeight: CGFloat?)
    case pushedDetail(transitionViewportHeightFloor: CGFloat)
}

/// Builds **`BlueSheetHeaderPageLayoutContext`** with identical hero/sheet proportions for Home and detail pages.
enum BlueSheetPageLayoutBuilder: Sendable {

    /// Hero band height from shared **`HomeOverviewLayout.metrics`** (+ leaderboard cap when applicable).
    nonisolated static func heroMetrics(
        layoutViewportHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs
    ) -> HomeOverviewLayout.Metrics {
        let primary = HomeOverviewLayout.metrics(
            viewportHeight: layoutViewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: seamInputs.statsPanelContentHeight
        )
        guard seamInputs.showsBuddyLeaderboard else { return primary }
        let capped = HomeOverviewLayout.metrics(
            viewportHeight: layoutViewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard
        )
        return HomeOverviewLayout.Metrics(
            heroHeight: min(primary.heroHeight, capped.heroHeight)
        )
    }

    nonisolated static func tabRootTabContentHeight(
        geometryHeight: CGFloat,
        isNavigationStackAtRoot: Bool,
        frozenRootViewportHeight: CGFloat?
    ) -> CGFloat {
        HomeTabRootLayoutPresentation.tabContentGeometryHeight(
            geometryHeight: geometryHeight,
            isNavigationStackAtRoot: isNavigationStackAtRoot,
            frozenTabContentGeometryHeight: frozenRootViewportHeight
        )
    }

    /// Tab-root layout uses virtual full-screen geometry — same inputs as pushed detail.
    nonisolated static func tabRootEffectiveFullScreenHeight(
        geometryHeight: CGFloat,
        isNavigationStackAtRoot: Bool,
        frozenRootViewportHeight: CGFloat?
    ) -> CGFloat {
        let tabContentHeight = tabRootTabContentHeight(
            geometryHeight: geometryHeight,
            isNavigationStackAtRoot: isNavigationStackAtRoot,
            frozenRootViewportHeight: frozenRootViewportHeight
        )
        return HomeTabRootLayoutPresentation.referenceFullScreenGeometryHeight(
            from: tabContentHeight
        )
    }

    nonisolated static func layoutViewportHeight(
        geometryHeight: CGFloat,
        mode: BlueSheetPageLayoutMode,
        transitionViewportHeightFloor: CGFloat = 0
    ) -> CGFloat {
        switch mode {
        case let .tabRoot(isNavigationStackAtRoot, frozenRootViewportHeight):
            let effectiveGeometry = tabRootEffectiveFullScreenHeight(
                geometryHeight: geometryHeight,
                isNavigationStackAtRoot: isNavigationStackAtRoot,
                frozenRootViewportHeight: frozenRootViewportHeight
            )
            return HomeOverviewLayout.pushedHeroLayoutViewportHeight(from: effectiveGeometry)
        case .pushedDetail:
            return HomeOverviewLayout.pushedHeroLayoutViewportHeight(
                from: geometryHeight,
                transitionViewportFloor: transitionViewportHeightFloor
            )
        }
    }

    nonisolated static func heroHeight(
        geometryHeight: CGFloat,
        screenWidth: CGFloat,
        rawGeometrySafeTop: CGFloat,
        layoutSafeAreaTopFloor: CGFloat,
        seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs,
        mode: BlueSheetPageLayoutMode,
        transitionViewportHeightFloor: CGFloat = 0
    ) -> CGFloat {
        if case .pushedDetail = mode,
           let anchored = HomeOverviewLayoutAnchor.matchingRootHeroHeight(
               screenWidth: screenWidth,
               topSafeAreaInset: rawGeometrySafeTop
           ) {
            return anchored
        }

        let effectiveGeometryHeight: CGFloat
        let transitionFloor: CGFloat

        switch mode {
        case let .tabRoot(isNavigationStackAtRoot, frozenRootViewportHeight):
            effectiveGeometryHeight = tabRootEffectiveFullScreenHeight(
                geometryHeight: geometryHeight,
                isNavigationStackAtRoot: isNavigationStackAtRoot,
                frozenRootViewportHeight: frozenRootViewportHeight
            )
            transitionFloor = 0
        case .pushedDetail:
            effectiveGeometryHeight = geometryHeight
            transitionFloor = transitionViewportHeightFloor
        }

        let layoutViewport = HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: effectiveGeometryHeight,
            transitionViewportFloor: transitionFloor
        )
        let topSafeAreaInset = HomeOverviewLayout.pushedHeroTopSafeAreaInset(
            rawGeometrySafeTop: rawGeometrySafeTop,
            transitionSafeTopFloor: layoutSafeAreaTopFloor
        )
        return heroMetrics(
            layoutViewportHeight: layoutViewport,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            seamInputs: seamInputs
        ).heroHeight
    }

    @MainActor
    static func make(
        proxy: GeometryProxy,
        headerClearance: CGFloat,
        layoutSafeAreaTopFloor: CGFloat,
        layoutViewportHeightFloor: CGFloat,
        seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs,
        mode: BlueSheetPageLayoutMode,
        showsHero: Bool,
        measuredTabBarClearance: CGFloat = 0
    ) -> BlueSheetHeaderPageLayoutContext {
        let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
        let safeTop = max(rawSafeTop, layoutSafeAreaTopFloor)
        let geometryHeight = max(proxy.size.height, 1)

        let transitionFloor: CGFloat
        if case .pushedDetail = mode {
            transitionFloor = layoutViewportHeightFloor
        } else {
            transitionFloor = 0
        }

        let layoutViewport = layoutViewportHeight(
            geometryHeight: geometryHeight,
            mode: mode,
            transitionViewportHeightFloor: transitionFloor
        )

        let heroSafeTop: CGFloat
        switch mode {
        case .tabRoot:
            heroSafeTop = rawSafeTop
        case .pushedDetail:
            heroSafeTop = proxy.safeAreaInsets.top
        }

        let heroHeight = Self.heroHeight(
            geometryHeight: geometryHeight,
            screenWidth: proxy.size.width,
            rawGeometrySafeTop: heroSafeTop,
            layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
            seamInputs: seamInputs,
            mode: mode,
            transitionViewportHeightFloor: transitionFloor
        )

        let stackFrameHeight: CGFloat
        let panelBottomSafeAreaInset: CGFloat
        let bottomScrollInset: CGFloat

        switch mode {
        case let .tabRoot(isNavigationStackAtRoot, frozenRootViewportHeight):
            let tabContentHeight = tabRootTabContentHeight(
                geometryHeight: geometryHeight,
                isNavigationStackAtRoot: isNavigationStackAtRoot,
                frozenRootViewportHeight: frozenRootViewportHeight
            )
            stackFrameHeight = HomeTabRootLayoutPresentation.stackFrameHeight(
                from: tabContentHeight
            )
            panelBottomSafeAreaInset = HomeTabRootLayoutPresentation.panelBottomSafeAreaInset(
                measuredTabBarClearance: measuredTabBarClearance,
                safeAreaBottom: proxy.safeAreaInsets.bottom
            )
            bottomScrollInset = proxy.safeAreaInsets.bottom + BlueSheetPageProportions.tabBarScrollInset
        case .pushedDetail:
            stackFrameHeight = HomeOverviewLayout.pushedPageLayoutHeight(
                from: geometryHeight,
                transitionViewportFloor: transitionFloor
            )
            panelBottomSafeAreaInset = 0
            bottomScrollInset = HomeOverviewLayout.pushedPageScrollBottomInset(
                safeAreaBottom: proxy.safeAreaInsets.bottom
            )
        }

        let topInset = AppScrollUnderHeaderListLayout.listTopInset(
            safeAreaTop: safeTop,
            headerClearance: headerClearance
        )
        let heroTopSafeAreaInset = HomeOverviewLayout.pushedHeroTopSafeAreaInset(
            rawGeometrySafeTop: heroSafeTop,
            transitionSafeTopFloor: layoutSafeAreaTopFloor
        )

        let headerScrollClearance = showsHero
            ? 0
            : max(0, topInset - AppTheme.Spacing.lg)

        return BlueSheetHeaderPageLayoutContext(
            geometryWidth: proxy.size.width,
            geometryHeight: geometryHeight,
            safeTop: safeTop,
            topInset: topInset,
            heroTopSafeAreaInset: heroTopSafeAreaInset,
            layoutHeight: stackFrameHeight,
            layoutViewportHeight: layoutViewport,
            heroHeight: heroHeight,
            bottomScrollInset: bottomScrollInset,
            panelBottomSafeAreaInset: panelBottomSafeAreaInset,
            headerScrollClearance: headerScrollClearance,
            presentation: mode.presentation
        )
    }
}

private extension BlueSheetPageLayoutMode {
    var presentation: BlueSheetPagePresentation {
        switch self {
        case .tabRoot: .tabRoot
        case .pushedDetail: .pushedDetail
        }
    }
}
