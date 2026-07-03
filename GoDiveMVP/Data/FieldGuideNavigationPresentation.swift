import Foundation

/// Field Guide tab **`NavigationStack`** chrome — tab bar visibility while browsing vs detail pushes.
enum FieldGuideNavigationPresentation: Sendable {
    enum TabBarVisibilityContext: Equatable, Sendable {
        case hub
        case categoryBrowse
        case subcategoryBrowse
        case pushedDetail
    }

    /// Keep the root tab bar visible on the hub and category / subcategory browse pages.
    nonisolated static func showsRootTabBar(for context: TabBarVisibilityContext) -> Bool {
        switch context {
        case .hub, .categoryBrowse, .subcategoryBrowse:
            return true
        case .pushedDetail:
            return false
        }
    }
}
