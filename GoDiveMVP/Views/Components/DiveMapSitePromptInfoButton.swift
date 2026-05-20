import SwiftUI

/// Reopens the **no dive site** prompt on the dive map tab after the user chose **Not now**.
struct DiveMapSitePromptInfoButton: View {
    let action: () -> Void

    private enum Layout {
        /// Matches dive tab / back control tap size (**48×48**).
        static let tapDimension: CGFloat = DiveActivityTabIcon.menuRowHeight
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppTheme.Colors.surfaceElevated, AppTheme.Colors.accentDeep)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                .frame(width: Layout.tapDimension, height: Layout.tapDimension)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add dive site")
        .accessibilityHint("Shows options to add a dive site for this dive")
        .accessibilityIdentifier("DiveActivity.MapSitePrompt.Info")
    }
}
