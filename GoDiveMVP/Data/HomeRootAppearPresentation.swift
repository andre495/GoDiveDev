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
        guard isCelebrationShellPrewarmActive else { return false }
        switch source {
        case .incidental:
            return !hasPerformedInitialHomeBuild
        case .initialRootAppear:
            return false
        }
    }
}
