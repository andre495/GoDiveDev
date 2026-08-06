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
/// iOS 18 `TabView` can leave one-shot `let` booleans and even plain `EnvironmentValues`
/// copies stale inside tab content after first mount (console: Field Guide stuck
/// `paused=true`, Logbook never paused off-tab). An **`@Observable`** store invalidates
/// every tab that reads **`selected`**.
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
