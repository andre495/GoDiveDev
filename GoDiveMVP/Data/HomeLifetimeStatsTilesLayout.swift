import CoreGraphics
import Foundation

/// Shared Home stats + **Top buddies** tile heights for UI and **`HomeLifetimeStatsPanelLayout`**.
/// With buddies: scroll content ≈ **340** pt (2×2 grid **200** + buddy **120** + gaps).
enum HomeLifetimeStatsTilesLayout: Sendable {

    nonisolated static let gridSpacing: CGFloat = 20
    nonisolated static let gridColumnCount = 2
    nonisolated static let highlightStatTileCount = 4

    /// Fixed height for empty and populated highlight tiles (same shell either way).
    nonisolated static let statTileHeight: CGFloat = 90
    nonisolated static let buddyTileHeight: CGFloat = 120

    /// Space above the lifetime summary line (below the sheet seam).
    nonisolated static let lifetimeSummaryTopInset: CGFloat = 8
    /// Approximate one-line summary height (`.subheadline`).
    nonisolated static let lifetimeSummaryLineHeight: CGFloat = 20
    nonisolated static let lifetimeSummaryHeaderSpacingBelow: CGFloat = 10

    nonisolated static func lifetimeSummaryBandHeight(includesHeader: Bool = true) -> CGFloat {
        guard includesHeader else { return 0 }
        return lifetimeSummaryTopInset + lifetimeSummaryLineHeight + lifetimeSummaryHeaderSpacingBelow
    }

    /// Minimum tile heights — flexible Home layout grows above these to fill the blue panel.
    nonisolated static var statTileMinimumHeight: CGFloat { statTileHeight }
    nonisolated static var buddyTileMinimumHeight: CGFloat { buddyTileHeight }

    nonisolated static let statTilePadding: CGFloat = 10
    nonisolated static let valueFontSize: CGFloat = 19
    nonisolated static let titleFontSize: CGFloat = 12

    /// Visual inset from the sheet seam and above tab-bar clearance — matches **`gridSpacing`** at minimum; extra panel height splits here (not between tiles).
    nonisolated static let panelTopContentPaddingWhenOverlapping: CGFloat = 0
    nonisolated static let panelBottomContentPadding: CGFloat = 0

    nonisolated static func scrollContentHeight(
        statRowCount: Int,
        showsBuddyLeaderboard: Bool,
        includesLifetimeSummaryHeader: Bool = true
    ) -> CGFloat {
        let rows = max(statRowCount, 0)
        guard rows > 0 else { return 0 }
        var height = CGFloat(rows) * statTileHeight
            + CGFloat(max(rows - 1, 0)) * gridSpacing
        if showsBuddyLeaderboard {
            height += gridSpacing + buddyTileHeight
        }
        height += lifetimeSummaryBandHeight(includesHeader: includesLifetimeSummaryHeader)
        return height
    }

    nonisolated static func gridHeight(tileCount: Int) -> CGFloat {
        guard tileCount > 0 else { return 0 }
        let rows = (tileCount + gridColumnCount - 1) / gridColumnCount
        return scrollContentHeight(statRowCount: rows, showsBuddyLeaderboard: false)
    }

    nonisolated static func scrollContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        let rowCount = (highlightStatTileCount + gridColumnCount - 1) / gridColumnCount
        return scrollContentHeight(
            statRowCount: rowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
    }

    nonisolated static func panelContentHeight(showsBuddyLeaderboard: Bool) -> CGFloat {
        scrollContentHeight(showsBuddyLeaderboard: showsBuddyLeaderboard)
    }

    /// Legacy minimum top band — seam estimates use intrinsic tile stack height only.
    nonisolated static let panelTopEdgeInset: CGFloat = gridSpacing

    /// Centers the tile stack vertically between the sheet seam and measured tab-bar top.
    nonisolated static func resolvedVerticalEdgeInsets(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool,
        includesLifetimeSummaryHeader: Bool = true
    ) -> (top: CGFloat, bottom: CGFloat) {
        let minContent = scrollContentHeight(
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard,
            includesLifetimeSummaryHeader: includesLifetimeSummaryHeader
        )
        guard totalHeight > 0, minContent > 0 else {
            return (0, 0)
        }
        guard totalHeight >= minContent else {
            return (0, 0)
        }
        let slack = totalHeight - minContent
        let half = slack / 2
        return (half, half)
    }

    /// Legacy single inset — minimum top band (tests / estimates).
    nonisolated static func resolvedVerticalEdgeInset(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool
    ) -> CGFloat {
        resolvedVerticalEdgeInsets(
            totalHeight: totalHeight,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        ).top
    }

    /// Row heights for flexible estimates (layout math / tests).
    nonisolated static func resolvedFlexibleLayoutHeights(
        totalHeight: CGFloat,
        statRowCount: Int,
        showsBuddyLeaderboard: Bool
    ) -> (statRowHeight: CGFloat, buddyRowHeight: CGFloat) {
        let rows = max(statRowCount, 0)
        let minStatRow = statTileHeight
        let statRowGaps = CGFloat(max(rows - 1, 0))
        let minStatGrid = CGFloat(rows) * minStatRow + statRowGaps * gridSpacing

        guard showsBuddyLeaderboard else {
            guard rows > 0 else { return (0, 0) }
            guard totalHeight > 0 else { return (minStatRow, 0) }
            guard totalHeight >= minStatGrid else {
                let scale = totalHeight / max(minStatGrid, 1)
                return (minStatRow * scale, 0)
            }
            let extra = totalHeight - minStatGrid
            return (minStatRow + extra / CGFloat(rows), 0)
        }

        let minBuddy = buddyTileHeight
        let minTotal = minStatGrid + gridSpacing + minBuddy
        guard totalHeight > 0 else {
            return (minStatRow, minBuddy)
        }
        guard totalHeight >= minTotal else {
            let scale = totalHeight / minTotal
            return (minStatRow * scale, minBuddy * scale)
        }

        let extra = totalHeight - minTotal
        let weightSum = CGFloat(rows) * minStatRow + minBuddy
        let statShare = (CGFloat(rows) * minStatRow) / weightSum
        return (
            minStatRow + extra * statShare / CGFloat(max(rows, 1)),
            minBuddy + extra * (1 - statShare)
        )
    }

    /// Splits flexible panel content height between the 2×2 grid block and **Top buddies** (legacy estimates).
    nonisolated static func resolvedFlexibleSectionHeights(
        totalHeight: CGFloat,
        showsBuddyLeaderboard: Bool
    ) -> (grid: CGFloat, buddy: CGFloat) {
        let rowCount = (highlightStatTileCount + gridColumnCount - 1) / gridColumnCount
        let rows = resolvedFlexibleLayoutHeights(
            totalHeight: totalHeight,
            statRowCount: rowCount,
            showsBuddyLeaderboard: showsBuddyLeaderboard
        )
        guard showsBuddyLeaderboard else {
            let minGrid = gridHeight(tileCount: highlightStatTileCount)
            return (max(rows.statRowHeight * CGFloat(rowCount) + statRowGaps(rowCount) * gridSpacing, minGrid), 0)
        }
        let minGrid = gridHeight(tileCount: highlightStatTileCount)
        return (
            max(rows.statRowHeight * CGFloat(rowCount) + statRowGaps(rowCount) * gridSpacing, minGrid),
            rows.buddyRowHeight
        )
    }

    private nonisolated static func statRowGaps(_ rowCount: Int) -> CGFloat {
        CGFloat(max(rowCount - 1, 0))
    }
}
