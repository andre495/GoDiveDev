import Foundation
import SwiftUI

/// Root **`TabView`** destinations (**`ContentView`**).
/// **`nonisolated`** so selection helpers / tests can compare without MainActor isolation.
nonisolated enum RootTab: Hashable, Sendable {
    case home
    case logbook
    case fieldGuide
    case explore
    case search
}

enum RootTabIndex {
    static let home = 0
    static let logbook = 1
    static let fieldGuide = 2
    static let explore = 3
}

/// Shared live root-tab selection (ContentView + diagnostics).
///
/// iOS 26 `TabView` can leave one-shot `let` booleans and even the SwiftUI `selection`
/// binding stale while **`UITabBarController`** still changes the visible tab. Keep this
/// store in sync from **`Notification.Name.rootTabBarDidSelect`** (UIKit `didSelect`) as
/// well as ContentView’s `selectedTab`.
///
/// Tab **bodies** must **not** read **`selected`** during `body` — that Observation fan-out
/// re-renders every reader on every switch. Mirror via **`rootTabSelectionDidChange`** into
/// local **`@State`** instead (see Logbook / Field Guide / Explore / Search).
@Observable
@MainActor
final class RootTabSelectionStore {
    var selected: RootTab = .home
}

/// Testable rules for root-tab selection side effects (bubbles, warm-up gates).
enum RootTabSelectionPresentation: Sendable {
    nonisolated static func isSelected(_ tab: RootTab, selected: RootTab) -> Bool {
        tab == selected
    }

    nonisolated static func shouldPauseBubbles(for tab: RootTab, selected: RootTab) -> Bool {
        tab != selected
    }

    /// Whether **`applyRootTabSelection`** should write the store + post
    /// **`rootTabSelectionDidChange`** (skip no-op UIKit + SwiftUI double-fires).
    nonisolated static func shouldPublishSelectionChange(
        previous: RootTab,
        next: RootTab
    ) -> Bool {
        previous != next
    }

    /// Tab bodies often mount **after** **`rootTabSelectionDidChange`** already fired on first
    /// select — seed local **`@State`** from the store on appear (do not read the store in
    /// **`body`**).
    nonisolated static func localSelectionAfterMount(
        tab: RootTab,
        storeSelected: RootTab
    ) -> Bool {
        isSelected(tab, selected: storeSelected)
    }

    /// Resolve a selection notification into a local selected flag for **`tab`**.
    nonisolated static func localSelection(
        tab: RootTab,
        from notification: Notification
    ) -> Bool? {
        guard let selected = RootTabBarSelectionSync.tab(from: notification) else { return nil }
        return isSelected(tab, selected: selected)
    }
}
