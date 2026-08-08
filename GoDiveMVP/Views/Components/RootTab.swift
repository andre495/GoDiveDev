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

/// Shared live root-tab selection.
///
/// iOS 26 `TabView` can leave one-shot `let` booleans and even the SwiftUI `selection`
/// binding stale while **`UITabBarController`** still changes the visible tab. Keep this
/// store in sync from **`Notification.Name.rootTabBarDidSelect`** (UIKit `didSelect`) as
/// well as ContentView’s `selectedTab` — tabs that only read SwiftUI selection will miss
/// Field Guide / Explore opens. An **`@Observable`** store invalidates every tab that
/// reads **`selected`**.
@Observable
@MainActor
final class RootTabSelectionStore {
    var selected: RootTab = .home
}

/// Testable rules for root-tab selection side effects (bubbles, warm-up gates).
enum RootTabSelectionPresentation: Sendable {
    static func isSelected(_ tab: RootTab, selected: RootTab) -> Bool {
        tab == selected
    }

    static func shouldPauseBubbles(for tab: RootTab, selected: RootTab) -> Bool {
        tab != selected
    }
}
