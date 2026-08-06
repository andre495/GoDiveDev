import Foundation

/// First **`LogOverviewView`** appear during celebration shell prewarm.
enum HomeRootAppearPresentation: Sendable {
    enum Action: Equatable, Sendable {
        case scheduleImmediateInitialRebuild
        case handleReturnToRoot
    }

    nonisolated static func handleRootAppearAction(
        hasPerformedInitialHomeBuild: Bool
    ) -> Action {
        hasPerformedInitialHomeBuild ? .handleReturnToRoot : .scheduleImmediateInitialRebuild
    }
}

/// Whether an incidental Home aggregate rebuild should be coalesced during shell prewarm.
enum HomeOverviewRebuildPresentation: Sendable {
    enum Source: Equatable, Sendable {
        case initialRootAppear
        case incidental
    }

    nonisolated static func shouldSkipSchedule(
        isCelebrationShellPrewarmActive: Bool,
        hasPerformedInitialHomeBuild: Bool,
        source: Source
    ) -> Bool {
        switch source {
        case .incidental:
            // Never interrupt the cold-launch scalar / carousel path.
            _ = isCelebrationShellPrewarmActive
            return !hasPerformedInitialHomeBuild
        case .initialRootAppear:
            return false
        }
    }

    nonisolated static func initialLaunchDebounceNanoseconds(
        immediate: Bool,
        source: Source
    ) -> UInt64 {
        guard immediate else { return 0 }
        switch source {
        case .initialRootAppear:
            return AppLaunchPostOverlayPresentation.initialHomeRebuildDeferNanoseconds
        case .incidental:
            return 0
        }
    }
}

/// Cold Home first paint: scalar launch path before background sighting enrichment.
enum HomeOverviewFirstPaintPresentation: Sendable {
    /// When the owner query already has dives, use scalar launch + pick-3 JPEG seed before full enrich.
    nonisolated static func shouldUseTwoPhaseInitialRebuild(
        hasPerformedInitialHomeBuild: Bool,
        ownerDiveActivityCount: Int
    ) -> Bool {
        !hasPerformedInitialHomeBuild && ownerDiveActivityCount > 0
    }
}

/// Splash dismiss — Home chrome ready must not depend on a single rebuild generation surviving.
enum HomeLaunchChromePresentation: Sendable {
    /// Mark ready after any successful Home aggregate apply while splash is still waiting.
    ///
    /// Do **not** gate on “was initial rebuild” — a superseded launch path can set
    /// **`hasPerformedInitialHomeBuild`** (or skip) such that a later rebuild never marks chrome.
    nonisolated static func shouldMarkChromeReady(isAlreadyReady: Bool) -> Bool {
        !isAlreadyReady
    }
}
