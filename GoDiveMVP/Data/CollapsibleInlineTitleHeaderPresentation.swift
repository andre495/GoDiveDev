import Foundation

/// Shared collapsible inline title chrome — Logbook-style row with scroll-offset compaction.
enum CollapsibleInlineTitleHeaderPresentation: Sendable {
    /// Scroll offset above which the title compacts (**`onScrollGeometryChange`** on the list).
    nonisolated static let collapseScrollOffsetThreshold: CGFloat = 8

    /// Extra fade below measured chrome (**`LogbookTopChromeScrim`** tail).
    nonisolated static let listScrollFadeFeatherHeight: CGFloat = 128

    /// Fixed width for leading / trailing columns — title uses the remaining row width.
    nonisolated static let sideControlWidth: CGFloat = 44

    /// **44** pt glass row + **`appTopChromeVerticalPadding`** (**8** + **16**).
    nonisolated static let chromeBandHeight: CGFloat = 68

    nonisolated static func isCollapsed(forScrollOffset offset: CGFloat) -> Bool {
        offset > collapseScrollOffsetThreshold
    }

    nonisolated static func topObstructionHeight(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + chromeBandHeight
    }

    nonisolated static func scrimBandHeight(safeAreaTop: CGFloat) -> CGFloat {
        topObstructionHeight(safeAreaTop: safeAreaTop) + listScrollFadeFeatherHeight
    }
}
