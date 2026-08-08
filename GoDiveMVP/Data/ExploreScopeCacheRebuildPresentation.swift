import Foundation

/// Gates Explore scope-cache rebuild / default scope so map pins are not blanked by
/// idle-tab dive-query timing (All Sites only needs the bundled reference catalog).
enum ExploreScopeCacheRebuildPresentation: Sendable {

    /// Scope-cache rebuild may start as soon as Explore is selected — do not wait for
    /// **`OwnerDiveActivitiesQueryBridge`** (All Sites pins come from ODM reference).
    nonisolated static func shouldScheduleScopeCacheRebuild(
        isExploreTabSelected: Bool
    ) -> Bool {
        isExploreTabSelected
    }

    /// Prefer the live dive snapshot once it has arrived; keep the latch so a transient
    /// empty bridge delivery cannot flip the default back to All Sites.
    nonisolated static func hasLoggedActivities(
        shouldMountLiveDiveQuery: Bool,
        hasReceivedLiveDiveSnapshot: Bool,
        liveActivityCount: Int,
        latchedHasLoggedActivities: Bool
    ) -> Bool {
        if liveActivityCount > 0 { return true }
        if latchedHasLoggedActivities { return true }
        if shouldMountLiveDiveQuery, hasReceivedLiveDiveSnapshot {
            return false
        }
        return false
    }

    /// Default My Sites / All Sites only after the live dive snapshot exists.
    nonisolated static func shouldApplyDefaultSiteScope(
        hasAppliedDefaultSiteScope: Bool,
        hasReceivedLiveDiveSnapshot: Bool
    ) -> Bool {
        !hasAppliedDefaultSiteScope && hasReceivedLiveDiveSnapshot
    }

    /// Do not flip the toggle to My Sites while that scope still has zero plottable pins —
    /// otherwise the map applies an empty set before the activity-aware rebuild lands.
    nonisolated static func shouldDeferDefaultLogbookScope(
        desiredScope: ExploreSiteScope,
        logbookPlottableCount: Int
    ) -> Bool {
        desiredScope == .logbook && logbookPlottableCount == 0
    }

    /// When the diver is known to have activities, do not paint All Sites first — wait for
    /// My Sites pins (loading placeholder) so the map does not flash the full catalog.
    nonisolated static func shouldPaintAllSitesSessionSeed(
        prefersLogbookDefault: Bool
    ) -> Bool {
        !prefersLogbookDefault
    }

    /// All Sites fallback while My Sites is empty.
    ///
    /// Wait only while a rebuild is in flight **and** logbook site IDs exist (My Sites pins
    /// are expected). Otherwise fall back immediately so a cancel storm / empty logbook
    /// links cannot leave the map on the loading placeholder forever.
    nonisolated static func shouldFallbackToAllSitesWhileLogbookEmpty(
        prefersLogbookDefault: Bool,
        isScopeCacheRebuildInFlight: Bool = false,
        expectsLogbookPins: Bool = false
    ) -> Bool {
        if prefersLogbookDefault, isScopeCacheRebuildInFlight, expectsLogbookPins {
            return false
        }
        return true
    }

    /// Clear the in-flight flag only for the rebuild generation that still owns the slot
    /// (a newer `scheduleScopeCacheRebuild` must not be cleared by a cancelled predecessor).
    nonisolated static func shouldClearRebuildInFlight(
        taskGeneration: UInt64,
        activeGeneration: UInt64
    ) -> Bool {
        taskGeneration == activeGeneration
    }

    /// Never publish an empty plottable set from an uninitialized cache (map wipe).
    nonisolated static func shouldApplyScopePresentation(isCacheEmpty: Bool) -> Bool {
        !isCacheEmpty
    }

    /// Whether the map loading placeholder should stay up — only while a rebuild is in flight.
    /// An empty cache with **no** in-flight work must not spin forever (show empty state instead).
    nonisolated static func shouldShowMapLoadingPlaceholder(
        displayedPlottableCount: Int,
        isScopeCacheRebuildInFlight: Bool,
        isCacheEmpty: Bool
    ) -> Bool {
        _ = isCacheEmpty
        return displayedPlottableCount == 0 && isScopeCacheRebuildInFlight
    }

    /// When My Sites is empty but All Sites has pins, either keep the current display,
    /// wait briefly while a rebuild is in flight **and** logbook pins are expected, or
    /// fall back to All Sites — never leave the map on the loading placeholder forever.
    nonisolated static func plottableSitesForDisplay(
        siteScope: ExploreSiteScope,
        scopedSitesCount: Int,
        allSitesCount: Int,
        currentlyDisplayingSites: Bool,
        prefersLogbookDefault: Bool = false,
        isScopeCacheRebuildInFlight: Bool = false,
        expectsLogbookPins: Bool = false
    ) -> PlottableDisplayDecision {
        if scopedSitesCount > 0 {
            return .useScopedSites
        }
        if siteScope == .logbook, allSitesCount > 0 {
            if currentlyDisplayingSites {
                return .keepCurrentDisplay
            }
            if prefersLogbookDefault, isScopeCacheRebuildInFlight, expectsLogbookPins {
                return .keepWaitingForLogbook
            }
            return .useAllSitesFallback
        }
        return .useScopedSites
    }

    enum PlottableDisplayDecision: Equatable, Sendable {
        case useScopedSites
        case useAllSitesFallback
        case keepCurrentDisplay
        /// Leave the map on the loading placeholder until the in-flight rebuild finishes.
        case keepWaitingForLogbook
    }

    /// When activities just arrived, the cache may still have empty My Sites while All Sites
    /// pins are on screen — keep them until the rebuild with the new sync token lands.
    nonisolated static func shouldReplaceDisplayedPlottableSites(
        incomingSitesEmpty: Bool,
        currentlyDisplayingSites: Bool,
        appliedSyncToken: String?,
        currentSyncToken: String
    ) -> Bool {
        if incomingSitesEmpty,
           currentlyDisplayingSites,
           appliedSyncToken != currentSyncToken {
            return false
        }
        return true
    }
}
