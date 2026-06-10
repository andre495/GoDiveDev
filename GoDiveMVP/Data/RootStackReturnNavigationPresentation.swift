import Foundation

/// Shared pop-to-root behavior for tab **`NavigationStack`** roots (Field Guide, Logbook, Explore).
enum RootStackReturnNavigationPresentation: Sendable {

    nonisolated static func isStackAtRoot(pathCount: Int) -> Bool {
        pathCount == 0
    }

    /// Logbook list rows are still valid after popping a dive — skip a redundant cache rebuild on root **`onAppear`**.
    nonisolated static func shouldSkipLogbookCacheRefreshOnReturn(
        hasPerformedInitialCacheBuild: Bool,
        hasDisplayRows: Bool
    ) -> Bool {
        hasPerformedInitialCacheBuild && hasDisplayRows
    }
}
