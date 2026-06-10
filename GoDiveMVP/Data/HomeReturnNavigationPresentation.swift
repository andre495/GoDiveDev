import Foundation

/// Home stack return behavior — avoid redundant rebuild work when popping Profile / buddy flows.
enum HomeReturnNavigationPresentation: Sendable {

    nonisolated static func shouldSkipFullRebuildOnReturn(
        hasPerformedInitialBuild: Bool,
        isCarouselMediaReady: Bool,
        hasCarouselHighlights: Bool
    ) -> Bool {
        hasPerformedInitialBuild && isCarouselMediaReady && hasCarouselHighlights
    }
}
