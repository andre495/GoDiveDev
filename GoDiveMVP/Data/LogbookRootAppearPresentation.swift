import Foundation

/// Logbook list cache builds are expensive — skip off-tab mount when the tab bar preloads Logbook,
/// and skip full rebuilds when the tab is merely re-selected with a warm list.
enum LogbookRootAppearPresentation: Sendable {

    /// First-paint cache build only — not a re-select refresh trigger.
    nonisolated static func shouldBuildCacheOnAppear(
        isLogbookTabSelected: Bool,
        hasPerformedInitialCacheBuild: Bool
    ) -> Bool {
        guard !hasPerformedInitialCacheBuild else { return false }
        return isLogbookTabSelected
    }

    /// Tab re-select / deferred build — rebuild only for first paint or an empty list that still has activities.
    nonisolated static func shouldRebuildCacheOnTabSelect(
        isLogbookTabSelected: Bool,
        hasPerformedInitialCacheBuild: Bool,
        hasDisplayRows: Bool,
        hasVisibleActivities: Bool
    ) -> Bool {
        guard isLogbookTabSelected else { return false }
        if !hasPerformedInitialCacheBuild { return true }
        return !hasDisplayRows && hasVisibleActivities
    }
}
