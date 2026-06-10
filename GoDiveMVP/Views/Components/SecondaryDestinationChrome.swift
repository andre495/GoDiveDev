import SwiftUI

extension View {
    /// Hides the root `TabView` bar while this view is shown (pushed inside a tab's `NavigationStack`).
    func hidesBottomTabBarWhenPushed() -> some View {
        toolbar(.hidden, for: .tabBar)
    }

    /// Re-shows the root tab bar as soon as a tab's **`NavigationStack`** returns to root.
    func restoresRootTabBarWhenStackIsEmpty(_ isStackEmpty: Bool) -> some View {
        #if canImport(UIKit)
        self
            .toolbar(isStackEmpty ? .visible : .automatic, for: .tabBar)
            .background {
                if isStackEmpty {
                    RootTabBarVisibilityInstaller()
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
import UIKit

enum RootTabBarVisibilityRestorer {
    @MainActor
    static func showTabBar(from view: UIView) {
        guard let tabBarController = view.nearestViewController?.tabBarController else { return }
        tabBarController.tabBar.isHidden = false
    }
}

private struct RootTabBarVisibilityInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            RootTabBarVisibilityRestorer.showTabBar(from: uiView)
        }
    }
}

private extension UIResponder {
    var nearestViewController: UIViewController? {
        sequence(first: self, next: \.next)
            .compactMap { $0 as? UIViewController }
            .first
    }
}
#endif

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
