import SwiftUI

/// Typography + spacing for **`BlueSheetPinnedSummary`** (Layer 2 pinned identity rows).
enum BlueSheetPinnedSummaryPresentation: Sendable {
    /// Matches **`BlueSheetDetailPagePinnedSummaryPresentation.pinnedRowSpacing`** on detail pages.
    nonisolated static let rowSpacing: CGFloat =
        BlueSheetDetailPagePinnedSummaryPresentation.pinnedRowSpacing

    nonisolated static var titleFont: Font { .title.weight(.bold) }
    nonisolated static var accentFont: Font { .subheadline.weight(.semibold) }
    nonisolated static var accentMediumFont: Font { .subheadline.weight(.medium) }
    nonisolated static var subtitleFont: Font { .subheadline }

    nonisolated static var buddyTitleFont: Font { .title2.weight(.bold) }
    nonisolated static var buddyAccentFont: Font { .body.weight(.semibold) }
}
