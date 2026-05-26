import SwiftUI

extension View {
    /// Hides the root `TabView` bar while this view is shown (pushed inside a tab's `NavigationStack`).
    func hidesBottomTabBarWhenPushed() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}

enum SecondaryDestinationChromeMetrics {
    /// Minimum tappable width/height for **`SecondaryDestinationBackButton`** (matches Logbook **+**).
    static let backButtonMinimumTapDimension: CGFloat = 44
}

struct SecondaryDestinationBackButton: View {
    @Environment(\.dismiss) private var dismiss

    /// Minimum tappable width/height (e.g. **44** matches Logbook **+**).
    var minTapDimension: CGFloat = SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension
    /// Runs immediately before **`dismiss()`** (e.g. drop MapKit before the pop animation).
    var onWillDismiss: (() -> Void)? = nil

    var body: some View {
        Button {
            onWillDismiss?()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(minWidth: minTapDimension, minHeight: minTapDimension)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.Colors.iconPrimary)
        .accessibilityLabel("Back")
    }
}
