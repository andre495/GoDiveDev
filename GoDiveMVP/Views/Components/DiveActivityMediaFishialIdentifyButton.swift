import SwiftUI

/// Opens Fishial fish identification for the selected dive media item.
struct DiveActivityMediaFishialIdentifyButton: View {
    let action: () -> Void

    private enum Layout {
        static let tapDimension: CGFloat = DiveActivityTabIcon.menuRowHeight
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: Layout.tapDimension, height: Layout.tapDimension)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Identify fish")
        .accessibilityHint("Uses Fishial AI to suggest species in this media")
        .accessibilityIdentifier("DiveActivity.Media.IdentifyFish")
    }
}
