import SwiftUI

/// Blank canvas with live hero + sheet region guides (Settings → **Layout geometry guide**).
struct PageLayoutGeometryReferenceView: View {
    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let geometryHeight = max(proxy.size.height, 1)
                let bottomInset = proxy.safeAreaInsets.bottom
                let layoutHeight = HomeOverviewLayout.pushedPageLayoutHeight(from: geometryHeight)
                let heroMetrics = HomeOverviewLayout.pushedHeroLayoutMetrics(
                    geometryHeight: geometryHeight,
                    screenWidth: proxy.size.width,
                    topSafeAreaInset: HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                        rawGeometrySafeTop: proxy.safeAreaInsets.top
                    )
                )
                let bottomScrollInset = HomeOverviewLayout.pushedPageScrollBottomInset(
                    safeAreaBottom: bottomInset
                )
                let layoutSnapshot = PageLayoutGeometryProbe.pushed(
                    pageKind: .layoutReference,
                    screenWidth: proxy.size.width,
                    geometryHeight: geometryHeight,
                    safeAreaTop: safeTop,
                    safeAreaBottom: bottomInset,
                    layoutStackHeight: layoutHeight,
                    heroHeight: heroMetrics.heroHeight,
                    scrollBottomInset: bottomScrollInset
                )

                ZStack(alignment: .top) {
                    VStack(spacing: -HomeLifetimeStatsLayout.panelOverlap) {
                        PushedHeroBand(
                            height: heroMetrics.heroHeight,
                            topSafeAreaInset: proxy.safeAreaInsets.top
                        ) {
                            Color.clear
                        }
                        .accessibilityIdentifier("PageLayoutGeometry.Reference.HeroBand")

                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityIdentifier("PageLayoutGeometry.Reference.SheetBand")
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .frame(width: proxy.size.width, height: layoutHeight, alignment: .top)
                    .overlay(alignment: .topLeading) {
                        PageLayoutGeometryOverlay(snapshot: layoutSnapshot)
                    }

                    AppHeader(
                        title: PageLayoutGeometryReferencePresentation.pageTitle,
                        showsBackButton: true,
                        showsBrandWordmark: false,
                        statusBarSafeAreaTop: safeTop
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .hidesBottomTabBarWhenPushed()
        .accessibilityIdentifier("PageLayoutGeometry.Reference.Root")
    }
}
