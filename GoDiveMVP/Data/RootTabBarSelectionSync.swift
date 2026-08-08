import Foundation

extension Notification.Name {
    /// Posted from **`UITabBarControllerDelegate.didSelect`** with **`RootTabBarSelectionSync.userInfoTabKey`**.
    /// iOS 26 `TabView` can change the visible tab without writing the SwiftUI `selection` binding —
    /// this is the reliable selection signal for **`RootTabSelectionStore`**.
    static let rootTabBarDidSelect = Notification.Name("GoDive.rootTabBarDidSelect")
}

/// Maps UIKit tab-bar indices (ContentView declaration order) ↔ **`RootTab`**.
enum RootTabBarSelectionSync: Sendable {
    nonisolated static let userInfoTabKey = "tab"
    /// Same name as **`Notification.Name.rootTabBarDidSelect`** — string form is safe from any isolation.
    nonisolated private static let didSelectNotificationRawName = "GoDive.rootTabBarDidSelect"

    /// Tab order must match **`ContentView`** `Tab(value:)` declaration (Home → Search).
    nonisolated static func rootTab(forTabBarIndex index: Int) -> RootTab? {
        switch index {
        case 0: return .home
        case 1: return .logbook
        case 2: return .fieldGuide
        case 3: return .explore
        case 4: return .search
        default: return nil
        }
    }

    nonisolated static func postDidSelect(index: Int) {
        guard let tab = rootTab(forTabBarIndex: index) else { return }
        NotificationCenter.default.post(
            name: Notification.Name(didSelectNotificationRawName),
            object: nil,
            userInfo: [userInfoTabKey: tab]
        )
    }

    nonisolated static func tab(from notification: Notification) -> RootTab? {
        notification.userInfo?[userInfoTabKey] as? RootTab
    }
}
