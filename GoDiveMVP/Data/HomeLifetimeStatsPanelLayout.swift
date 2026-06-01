import CoreGraphics
import Foundation

/// Nonisolated Home lifetime-stats panel height estimates for **`HomeOverviewLayout`**.
enum HomeLifetimeStatsPanelLayout: Sendable {

    nonisolated static func estimatedScrollContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        HomeLifetimeStatsTilesLayout.scrollContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }

    nonisolated static func estimatedPanelContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        HomeLifetimeStatsTilesLayout.panelContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }
}
