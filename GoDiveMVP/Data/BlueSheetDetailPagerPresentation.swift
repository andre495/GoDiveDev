import CoreGraphics
import Foundation

/// Shared tokens for **`BlueSheetDetailPager`** page chrome.
enum BlueSheetDetailPagerPresentation: Sendable {
    nonisolated static let scrollPageSpacing: CGFloat = AppTheme.Spacing.lg
    nonisolated static let tripScrollBottomInsetExtra: CGFloat = AppTheme.Spacing.lg
    /// Gap between the pinned content-area title row and scroll/static page body.
    nonisolated static let pinnedPageHeaderBottomSpacing: CGFloat = AppTheme.Spacing.md
}
