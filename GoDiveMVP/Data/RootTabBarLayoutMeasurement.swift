import CoreGraphics
import Foundation
import SwiftUI

/// Fallback + resolved tab-bar clearance for Home tab-root stats panel inset.
enum RootTabBarLayoutMeasurement: Sendable {

    nonisolated static var fallbackTabBarHeight: CGFloat {
        HomeOverviewLayout.rootTabBarLayoutHeight
    }

    nonisolated static func estimatedClearanceAboveTabBar(safeAreaBottom: CGFloat) -> CGFloat {
        fallbackTabBarHeight + safeAreaBottom
    }

    nonisolated static func resolvedPanelBottomSafeAreaInset(
        measuredTabBarClearance: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        if measuredTabBarClearance > 0 {
            return measuredTabBarClearance
        }
        return estimatedClearanceAboveTabBar(safeAreaBottom: safeAreaBottom)
    }
}

enum RootTabBarClearanceMetrics {
    struct HeightKey: PreferenceKey {
        static let defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            let next = nextValue()
            guard next > 0 else { return }
            if value <= 0 || abs(next - value) > 0.5 {
                value = next
            }
        }
    }
}

#if canImport(UIKit)
import UIKit

extension RootTabBarLayoutMeasurement {
    /// Distance from the physical screen bottom up to the top edge of the visible root **`UITabBar`**.
    @MainActor
    static func measuredClearanceAboveTabBar(from anchorView: UIView) -> CGFloat? {
        guard let window = anchorView.window else { return nil }
        guard let tabBarController = anchorView.nearestViewController?.tabBarController else { return nil }

        let tabBar = tabBarController.tabBar
        guard !tabBar.isHidden, tabBar.alpha > 0.01 else { return nil }

        let tabBarFrame = tabBar.convert(tabBar.bounds, to: window)
        let clearance = window.bounds.maxY - tabBarFrame.minY
        guard clearance.isFinite, clearance > 0 else { return nil }
        return clearance
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
