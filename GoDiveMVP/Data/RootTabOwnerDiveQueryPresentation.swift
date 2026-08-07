import Foundation

/// When idle root tabs should (not) hold a live full-owner dive/snorkel `@Query`.
///
/// iOS `TabView` keeps every tab mounted. Live owner-wide dive queries on Logbook /
/// Field Guide / Explore / Search multiply SwiftData invalidation cost. Home stays the
/// always-live publisher; other tabs mount observation only while selected (Search:
/// first visit).
enum RootTabOwnerDiveQueryPresentation: Sendable {

    /// Mount a live owner dive `@Query` while the tab is selected, or while a dive
    /// detail remains on the stack and still needs the live array (legacy lookups).
    nonisolated static func shouldMountLiveOwnerDiveQuery(
        isTabSelected: Bool,
        pathContainsDiveDetail: Bool = false
    ) -> Bool {
        isTabSelected || pathContainsDiveDetail
    }

    /// Search index warmer: defer first mount until the Search tab is selected.
    nonisolated static func shouldScheduleSearchIndexMount(
        isSearchTabSelected: Bool,
        isSearchIndexMounted: Bool
    ) -> Bool {
        isSearchTabSelected && !isSearchIndexMounted
    }

    /// Never publish an empty owner dive index from an idle/unselected tab snapshot.
    nonisolated static func shouldPublishOwnerDiveIndex(
        isTabSelected: Bool,
        activityCount: Int
    ) -> Bool {
        isTabSelected && activityCount > 0
    }
}
