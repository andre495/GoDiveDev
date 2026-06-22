import Foundation

/// Home stack return behavior — avoid redundant rebuild work when popping Profile / buddy flows.
enum HomeReturnNavigationPresentation: Sendable {

    nonisolated static func shouldSkipFullRebuildOnReturn(
        hasPerformedInitialBuild: Bool,
        carouselSlidesAreDisplayable: Bool,
        hasCarouselHighlights: Bool
    ) -> Bool {
        hasPerformedInitialBuild && carouselSlidesAreDisplayable && hasCarouselHighlights
    }
}
