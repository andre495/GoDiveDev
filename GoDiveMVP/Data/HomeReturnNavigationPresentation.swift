import Foundation

/// Home foreground + return navigation — avoid redundant aggregate rebuilds.
enum HomeReturnNavigationPresentation: Sendable {

    /// Skip a full aggregate pass when Home has already built once and the cached aggregate is warm
    /// (including an empty logbook). Prefer carousel PhotoKit warm-up instead.
    nonisolated static func shouldSkipFullRebuildOnReturn(
        hasPerformedInitialBuild: Bool,
        hasWarmAggregate: Bool
    ) -> Bool {
        hasPerformedInitialBuild && hasWarmAggregate
    }

    /// Foreground (**`scenePhase == .active`**) should not rerun a full Home aggregate pass when the dashboard is already warm.
    nonisolated static func shouldSkipFullRebuildOnForegroundActivation(
        hasPerformedInitialBuild: Bool,
        hasWarmAggregate: Bool
    ) -> Bool {
        shouldSkipFullRebuildOnReturn(
            hasPerformedInitialBuild: hasPerformedInitialBuild,
            hasWarmAggregate: hasWarmAggregate
        )
    }

    /// Aggregate is warm after any completed build, including empty-logbook results.
    nonisolated static func hasWarmAggregate(
        hasPerformedInitialBuild: Bool
    ) -> Bool {
        hasPerformedInitialBuild
    }
}
