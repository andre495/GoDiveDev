import CoreGraphics
import Foundation

/// Static sheet-shaped stats panel over the sightings heat map (mirrors Home lifetime-stats layout).
enum FieldGuideSightingsOverviewLayout: Sendable {
    /// Same overlap as **`HomeLifetimeStatsLayout.panelOverlap`** so the map reads through rounded top corners.
    nonisolated static let panelOverlap: CGFloat = HomeOverviewLayout.panelOverlap

    nonisolated static func estimatedPanelContentHeight(
        regionCount: Int,
        showsEmptyState: Bool
    ) -> CGFloat {
        let titleBlock: CGFloat = 108
        let statsRow: CGFloat = 52
        let emptyState: CGFloat = showsEmptyState ? 56 : 0
        let regionSection: CGFloat = regionCount > 0 ? 28 + CGFloat(regionCount) * 26 : 0
        // Kept in sync with **`HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping`** (lg + sm)
        // and **`HomeOverviewLayout.tabBarScrollInset`**.
        let verticalPadding: CGFloat = 32 + 8 + HomeOverviewLayout.tabBarScrollInset
        return titleBlock + statsRow + emptyState + regionSection + verticalPadding
    }
}
