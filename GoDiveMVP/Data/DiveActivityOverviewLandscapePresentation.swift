import CoreGraphics
import Foundation

/// Landscape layout on **`ViewSingleActivity`** — full-bleed heroes, embedded sheet hidden.
enum DiveActivityOverviewLandscapePresentation: Sendable {

    nonisolated static func isLandscapeLayout(layoutSize: CGSize) -> Bool {
        layoutSize.width > layoutSize.height
    }

    /// Map / tank / media tabs hide the overview sheet in landscape at every detent.
    nonisolated static func hidesOverviewPanel(isLandscape: Bool) -> Bool {
        isLandscape
    }

    /// Full-screen map is interactive in landscape even when the resting detent is not **minimized**.
    nonisolated static func allowsMapInteraction(
        isLandscape: Bool,
        detentAllowsInteraction: Bool
    ) -> Bool {
        isLandscape || detentAllowsInteraction
    }

    /// Bottom inset for map camera / **`GMSMapView.padding`** — full sheet height from the physical bottom (incl. safe area).
    nonisolated static func mapBottomContentMargin(
        layoutContext: DiveActivityOverviewSheetLayoutContext,
        detent: DiveActivityOverviewDetent,
        liveHeightFraction: CGFloat?,
        isLandscape: Bool
    ) -> CGFloat {
        if isLandscape {
            return layoutContext.bottomSafeInset
        }
        if let liveHeightFraction {
            return DiveActivityOverviewDetent.sheetHeight(
                forHeightFraction: liveHeightFraction,
                layoutHeight: layoutContext.layoutHeight,
                bottomSafeInset: layoutContext.bottomSafeInset
            )
        }
        return DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutContext.layoutHeight,
            detent: detent,
            bottomSafeInset: layoutContext.bottomSafeInset,
            screenWidth: layoutContext.screenWidth,
            topSafeInset: layoutContext.topSafeInset
        )
    }

    /// **Media** hero is full-bleed in landscape regardless of detent.
    nonisolated static func mediaUsesFullBleedHero(
        isLandscape: Bool,
        detentUsesFullBleed: Bool
    ) -> Bool {
        isLandscape || detentUsesFullBleed
    }
}
