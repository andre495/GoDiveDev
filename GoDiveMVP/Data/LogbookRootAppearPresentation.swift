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

    /// Tab re-select / deferred build — rebuild when there are activities to paint (or the
    /// list is empty while activities exist).
    ///
    /// A cold start with **zero** visible activities must **not** latch the initial build —
    /// SwiftData `@Query` often flashes `[]` before rows appear; building that empty set and
    /// marking the cache “done” left My Activities blank until a full relaunch.
    nonisolated static func shouldRebuildCacheOnTabSelect(
        isLogbookTabSelected: Bool,
        hasPerformedInitialCacheBuild: Bool,
        hasDisplayRows: Bool,
        hasVisibleActivities: Bool
    ) -> Bool {
        guard isLogbookTabSelected else { return false }
        guard hasVisibleActivities else { return false }
        if !hasPerformedInitialCacheBuild { return true }
        return !hasDisplayRows
    }

    /// Never replace a painted list with an empty cache result while the store still has activities.
    nonisolated static func shouldApplyDisplayCacheResult(
        incomingItemCount: Int,
        visibleActivityCount: Int
    ) -> Bool {
        if incomingItemCount == 0, visibleActivityCount > 0 {
            return false
        }
        return true
    }
}
