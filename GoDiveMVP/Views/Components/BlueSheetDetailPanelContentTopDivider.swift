import SwiftUI

/// Thin rule between pinned title / identity block and pager body on **`BlueSheetDetailPage`**.
struct BlueSheetDetailPanelContentTopDivider: View {
    var body: some View {
        Rectangle()
            .fill(BlueSheetDetailPanelContentTopDividerPresentation.lineColor)
            .frame(height: BlueSheetDetailPanelContentTopDividerPresentation.lineHeight)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            .accessibilityIdentifier("BlueSheet.PanelContentTopDivider")
    }
}

enum BlueSheetDetailPanelContentTopDividerPresentation: Sendable {
    nonisolated static let lineHeight: CGFloat = 1

    /// Dark ocean blue in light mode; light ocean blue in dark mode (matches **`AppTheme.Colors.accentDeep`**).
    nonisolated static var lineColor: Color {
        AdaptiveAccentColor.color(
            light: AdaptiveAccentColor.RGB(red: 0.00, green: 0.18, blue: 0.36),
            dark: AdaptiveAccentColor.RGB(red: 0.64, green: 0.90, blue: 1.00)
        )
    }
}
