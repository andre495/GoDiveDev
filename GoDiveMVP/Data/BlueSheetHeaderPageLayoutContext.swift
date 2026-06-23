import CoreGraphics
import SwiftUI

/// Resolved layout numbers for a **blue sheet header page** (trip / buddy detail pattern).
struct BlueSheetHeaderPageLayoutContext: Sendable, Equatable {
    let geometryWidth: CGFloat
    let geometryHeight: CGFloat
    let safeTop: CGFloat
    let topInset: CGFloat
    let heroTopSafeAreaInset: CGFloat
    let layoutHeight: CGFloat
    let heroHeight: CGFloat
    let bottomScrollInset: CGFloat
    let headerScrollClearance: CGFloat

    /// Hero map fit when the page shows dive-site pins in the header band.
    func mapFitLayout(topObstructionHeight: CGFloat? = nil) -> TripDetailMapFitLayout {
        TripDetailMapFitLayout(
            mapHeight: heroHeight,
            topObstructionHeight: topObstructionHeight ?? topInset
        )
    }
}

/// Builds **`BlueSheetHeaderPageLayoutContext`** from a **`GeometryReader`** pass — same math as **`TripDetailView`** / **`ViewDiveBuddyDetails`**.
enum BlueSheetHeaderPageLayoutBuilder: Sendable {

    @MainActor
    static func make(
        proxy: GeometryProxy,
        headerClearance: CGFloat,
        layoutSafeAreaTopFloor: CGFloat,
        layoutViewportHeightFloor: CGFloat,
        heroHeight: CGFloat,
        showsHero: Bool
    ) -> BlueSheetHeaderPageLayoutContext {
        let rawSafeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
        let safeTop = max(rawSafeTop, layoutSafeAreaTopFloor)
        let geometryHeight = max(proxy.size.height, 1)
        let layoutHeight = HomeOverviewLayout.pushedPageLayoutHeight(
            from: geometryHeight,
            transitionViewportFloor: layoutViewportHeightFloor
        )
        let topInset = AppScrollUnderHeaderListLayout.listTopInset(
            safeAreaTop: safeTop,
            headerClearance: headerClearance
        )
        let heroTopSafeAreaInset = HomeOverviewLayout.pushedHeroTopSafeAreaInset(
            rawGeometrySafeTop: proxy.safeAreaInsets.top,
            transitionSafeTopFloor: layoutSafeAreaTopFloor
        )
        let bottomScrollInset = HomeOverviewLayout.pushedPageScrollBottomInset(
            safeAreaBottom: proxy.safeAreaInsets.bottom
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
            layoutHeight: layoutHeight,
            heroHeight: heroHeight,
            bottomScrollInset: bottomScrollInset,
            headerScrollClearance: headerScrollClearance
        )
    }

    /// Hero height using shared **`HomeOverviewLayout.pushedHeroLayoutMetrics`** (pass feature-specific seam inputs).
    nonisolated static func heroHeight(
        geometryHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat,
        showsBuddyLeaderboard: Bool,
        transitionViewportFloor: CGFloat
    ) -> CGFloat {
        HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: geometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsPanelContentHeight,
            showsBuddyLeaderboard: showsBuddyLeaderboard,
            transitionViewportFloor: transitionViewportFloor
        ).heroHeight
    }
}
