import CoreGraphics
import Foundation

/// Home lifetime-stat leaderboard page layout (podium + ranked list).
enum HomeLifetimeStatsLeaderboardLayout: Sendable {

    nonisolated static let podiumSectionMinHeight: CGFloat = 196
    nonisolated static let firstPlacePedestalHeight: CGFloat = 92
    nonisolated static let secondPlacePedestalHeight: CGFloat = 68
    nonisolated static let thirdPlacePedestalHeight: CGFloat = 52
    nonisolated static let podiumSlotSpacing: CGFloat = 10
    nonisolated static let podiumMedalIconSize: CGFloat = 28
    nonisolated static let listRankBadgeWidth: CGFloat = 32

    enum PodiumHorizontalPlacement: Sendable, Equatable {
        case left
        case center
        case right
    }

    struct PodiumSlot: Sendable, Equatable {
        let rank: Int
        let placement: PodiumHorizontalPlacement
    }

    /// Classic podium order: 2nd left, 1st center, 3rd right — only slots that exist.
    nonisolated static func podiumSlots(entryCount: Int) -> [PodiumSlot] {
        guard entryCount > 0 else { return [] }
        if entryCount == 1 {
            return [PodiumSlot(rank: 1, placement: .center)]
        }
        if entryCount == 2 {
            return [
                PodiumSlot(rank: 2, placement: .left),
                PodiumSlot(rank: 1, placement: .center),
            ]
        }
        return [
            PodiumSlot(rank: 2, placement: .left),
            PodiumSlot(rank: 1, placement: .center),
            PodiumSlot(rank: 3, placement: .right),
        ]
    }

    nonisolated static func pedestalHeight(for rank: Int) -> CGFloat {
        switch rank {
        case 1:
            return firstPlacePedestalHeight
        case 2:
            return secondPlacePedestalHeight
        default:
            return thirdPlacePedestalHeight
        }
    }

    nonisolated static func rankMedalSymbol(for rank: Int) -> String {
        switch rank {
        case 1:
            return "trophy.fill"
        case 2, 3:
            return "medal.fill"
        default:
            return "\(rank).circle.fill"
        }
    }
}
