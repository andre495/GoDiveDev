import SwiftUI

/// Corner control on dive media sheet chrome — opens tagged-buddy overview.
struct DiveActivityMediaBuddyTagButton: View {
    var isActive = false
    let action: () -> Void

    private enum Layout {
        static let tapDimension: CGFloat = DiveActivityTabIcon.menuRowHeight
    }

    private var iconColor: Color {
        isActive ? AppTheme.Colors.accent : AppTheme.Colors.tabUnselected
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.2.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: Layout.tapDimension, height: Layout.tapDimension)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Buddies")
        .accessibilityHint("Shows buddies tagged on this photo")
        .accessibilityIdentifier("DiveActivity.Media.TagBuddies")
    }
}
