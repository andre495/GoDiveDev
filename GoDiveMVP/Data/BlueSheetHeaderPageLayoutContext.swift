import CoreGraphics
import SwiftUI

/// Resolved layout numbers for a **blue sheet header page** (Home tab root + pushed detail).
struct BlueSheetHeaderPageLayoutContext: Sendable, Equatable {
    let geometryWidth: CGFloat
    let geometryHeight: CGFloat
    let safeTop: CGFloat
    let topInset: CGFloat
    let heroTopSafeAreaInset: CGFloat
    let layoutHeight: CGFloat
    let layoutViewportHeight: CGFloat
    let heroHeight: CGFloat
    let bottomScrollInset: CGFloat
    let panelBottomSafeAreaInset: CGFloat
    let headerScrollClearance: CGFloat
    let presentation: BlueSheetPagePresentation

    /// Hero map fit when the page shows dive-site pins in the header band.
    func mapFitLayout(topObstructionHeight: CGFloat? = nil) -> TripDetailMapFitLayout {
        TripDetailMapFitLayout(
            mapHeight: heroHeight,
            topObstructionHeight: topObstructionHeight ?? topInset
        )
    }
}

/// Builds **`BlueSheetHeaderPageLayoutContext`** — delegates to **`BlueSheetPageLayoutBuilder`**.
enum BlueSheetHeaderPageLayoutBuilder: Sendable {

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
        let resolvedMode: BlueSheetPageLayoutMode
        if case .pushedDetail = mode, layoutViewportHeightFloor > 0 {
            resolvedMode = .pushedDetail(transitionViewportHeightFloor: layoutViewportHeightFloor)
        } else {
            resolvedMode = mode
        }

        return BlueSheetPageLayoutBuilder.make(
            proxy: proxy,
            headerClearance: headerClearance,
            layoutSafeAreaTopFloor: layoutSafeAreaTopFloor,
            layoutViewportHeightFloor: layoutViewportHeightFloor,
            seamInputs: seamInputs,
            mode: resolvedMode,
            showsHero: showsHero,
            measuredTabBarClearance: measuredTabBarClearance
        )
    }

    /// Hero height using shared **`BlueSheetPageLayoutBuilder`** proportions.
    nonisolated static func heroHeight(
        geometryHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat,
        statsPanelContentHeight: CGFloat,
        showsBuddyLeaderboard: Bool,
        transitionViewportFloor: CGFloat
    ) -> CGFloat {
        BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: geometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: HomeOverviewPushedLayoutPresentation.SeamInputs(
                statsPanelContentHeight: statsPanelContentHeight,
                showsBuddyLeaderboard: showsBuddyLeaderboard
            ),
            mode: .pushedDetail(transitionViewportHeightFloor: transitionViewportFloor)
        )
    }
}
