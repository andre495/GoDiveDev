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

    /// Map camera uses only the bottom safe inset when the sheet is hidden.
    nonisolated static func mapBottomContentMargin(
        layoutHeight: CGFloat,
        detent: DiveActivityOverviewDetent,
        bottomSafeInset: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        if isLandscape {
            return bottomSafeInset
        }
        return DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutHeight,
            detent: detent,
            bottomSafeInset: bottomSafeInset
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
