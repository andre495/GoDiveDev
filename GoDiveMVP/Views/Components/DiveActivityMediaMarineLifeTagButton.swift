import SwiftUI

/// Corner control on dive media hero — opens tagged marine-life overview.
struct DiveActivityMediaMarineLifeTagButton: View {
    let action: () -> Void

    private enum Layout {
        static let tapDimension: CGFloat = DiveActivityTabIcon.menuRowHeight
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "fish.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: Layout.tapDimension, height: Layout.tapDimension)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Marine life")
        .accessibilityHint("Shows species tagged on this photo")
        .accessibilityIdentifier("DiveActivity.Media.TagMarineLife")
    }
}
