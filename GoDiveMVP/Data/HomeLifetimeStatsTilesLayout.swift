import CoreGraphics
import Foundation

/// Shared Home stats + **Top buddies** tile heights for UI and **`HomeLifetimeStatsPanelLayout`**.
/// With buddies: **368** pt scroll content (2×2 grid **200** + buddy **152** + gaps).
enum HomeLifetimeStatsTilesLayout: Sendable {

    nonisolated static let gridSpacing: CGFloat = 16
    nonisolated static let gridColumnCount = 2
    nonisolated static let highlightStatTileCount = 4

    nonisolated static let statTileHeight: CGFloat = 92
    nonisolated static let buddyTileHeight: CGFloat = 152

    nonisolated static let statTilePadding: CGFloat = 10
    nonisolated static let valueFontSize: CGFloat = 21
    nonisolated static let titleFontSize: CGFloat = 13

    nonisolated static func gridHeight(tileCount: Int) -> CGFloat {
        guard tileCount > 0 else { return 0 }
        let rows = (tileCount + gridColumnCount - 1) / gridColumnCount
        return CGFloat(rows) * statTileHeight + gridSpacing * CGFloat(max(rows - 1, 0))
    }

    nonisolated static func scrollContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        var height = gridHeight(tileCount: highlightStatTileCount)
        if showsBuddyLeaderboard {
            height += gridSpacing + buddyTileHeight
        }
        return height
    }

    nonisolated static func panelContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        let panelTopPaddingWhenOverlapping: CGFloat = 32
        let panelBottomPadding: CGFloat = 8
        return scrollContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
            + panelTopPaddingWhenOverlapping
            + panelBottomPadding
    }
}
