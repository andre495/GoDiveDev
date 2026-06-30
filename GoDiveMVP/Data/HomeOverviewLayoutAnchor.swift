import CoreGraphics
import Foundation

/// Last settled **`LogOverviewView`** root layout — pushed buddy/trip pages reuse this for **`screenBot`** alignment.
@MainActor
enum HomeOverviewLayoutAnchor {

    struct RootSnapshot: Sendable, Equatable {
        let heroHeight: CGFloat
        let screenWidth: CGFloat
        let topSafeAreaInset: CGFloat
        let statsPanelContentHeight: CGFloat
        let showsBuddyLeaderboard: Bool
        let homeTabViewportHeight: CGFloat
    }

    private nonisolated(unsafe) static var _root: RootSnapshot?

    nonisolated static var root: RootSnapshot? {
        _root
    }

    static func publish(_ snapshot: RootSnapshot) {
        guard _root != snapshot else { return }
        _root = snapshot
    }

    /// Publishes the latest settled **`BlueSheetTabRootPage`** layout for pushed detail seam sync.
    static func publishHomeTabRootLayout(
        _ layout: BlueSheetHeaderPageLayoutContext,
        statsPanelContentHeight: CGFloat,
        showsBuddyLeaderboard: Bool
    ) {
        publish(
            RootSnapshot(
                heroHeight: layout.heroHeight,
                screenWidth: layout.geometryWidth,
                topSafeAreaInset: layout.heroTopSafeAreaInset,
                statsPanelContentHeight: statsPanelContentHeight,
                showsBuddyLeaderboard: showsBuddyLeaderboard,
                homeTabViewportHeight: layout.layoutViewportHeight
            )
        )
    }

    #if DEBUG
    static func resetForTesting() {
        _root = nil
    }
    #endif

    nonisolated static func matchingRootHeroHeight(
        screenWidth: CGFloat,
        topSafeAreaInset: CGFloat
    ) -> CGFloat? {
        guard let root else { return nil }
        guard abs(root.screenWidth - screenWidth) < 1,
              abs(root.topSafeAreaInset - topSafeAreaInset) < 1 else {
            return nil
        }
        return root.heroHeight
    }

    nonisolated static func matchingRootSeamInputs() -> (statsPanelContentHeight: CGFloat, showsBuddyLeaderboard: Bool)? {
        guard let root else { return nil }
        return (root.statsPanelContentHeight, root.showsBuddyLeaderboard)
    }
}
