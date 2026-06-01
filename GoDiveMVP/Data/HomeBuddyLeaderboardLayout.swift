import CoreGraphics
import Foundation

/// Home **Top buddies** tile sizing (kept in **Data** for panel layout estimates).
enum HomeBuddyLeaderboardLayout: Sendable {
    nonisolated static let estimatedTileHeight: CGFloat = HomeLifetimeStatsTilesLayout.buddyTileHeight
    nonisolated static let podiumRowHeight: CGFloat = 98
    nonisolated static let avatarDiameter: CGFloat = 52
}
