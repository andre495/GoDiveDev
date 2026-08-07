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

    /// All Sites fallback while My Sites is empty — skipped when we already prefer My Sites.
    nonisolated static func shouldFallbackToAllSitesWhileLogbookEmpty(
        prefersLogbookDefault: Bool
    ) -> Bool {
        !prefersLogbookDefault
    }

    /// Never publish an empty plottable set from an uninitialized cache (map wipe).
    nonisolated static func shouldApplyScopePresentation(isCacheEmpty: Bool) -> Bool {
        !isCacheEmpty
    }

    /// When My Sites is empty but All Sites has pins, either keep the current display or
    /// fall back to All Sites for first paint — never leave the map blank.
    /// Prefer **`keepWaitingForLogbook`** when the default should be My Sites.
    nonisolated static func plottableSitesForDisplay(
        siteScope: ExploreSiteScope,
        scopedSitesCount: Int,
        allSitesCount: Int,
        currentlyDisplayingSites: Bool,
        prefersLogbookDefault: Bool = false
    ) -> PlottableDisplayDecision {
        if scopedSitesCount > 0 {
            return .useScopedSites
        }
        if siteScope == .logbook, allSitesCount > 0 {
            if prefersLogbookDefault {
                return currentlyDisplayingSites ? .keepCurrentDisplay : .keepWaitingForLogbook
            }
            if currentlyDisplayingSites {
                return .keepCurrentDisplay
            }
            return .useAllSitesFallback
        }
        return .useScopedSites
    }

    enum PlottableDisplayDecision: Equatable, Sendable {
        case useScopedSites
        case useAllSitesFallback
        case keepCurrentDisplay
        /// Leave the map on the loading placeholder until My Sites pins are ready.
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
