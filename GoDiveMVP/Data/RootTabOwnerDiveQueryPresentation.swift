import Foundation

/// When idle root tabs should (not) hold a live full-owner dive/snorkel `@Query`.
///
/// iOS 26 `TabView` keeps tab destinations mounted — do not hide them behind a
/// `Color.clear` lazy wrapper (that blacks out after the first tab change). Cut idle
/// cost with selection gates instead: Explore dive bridge via
/// **`shouldMountLiveOwnerDiveQuery`**; Search index via **`shouldScheduleSearchIndexMount`**;
/// Field Guide / Explore catalog binds via **`LazyRootTabPresentation.catalogBindStart`**
/// / **`waitUntilCatalogBindAllowed`** (idle after Home chrome quiet window; immediate when selected).
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
