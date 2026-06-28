import Foundation

/// Home foreground + return navigation — avoid redundant aggregate rebuilds.
enum HomeReturnNavigationPresentation: Sendable {

    nonisolated static func shouldSkipFullRebuildOnReturn(
        hasPerformedInitialBuild: Bool,
        carouselSlidesAreDisplayable: Bool,
        hasCarouselHighlights: Bool
    ) -> Bool {
        hasPerformedInitialBuild && carouselSlidesAreDisplayable && hasCarouselHighlights
    }

    /// Foreground (**`scenePhase == .active`**) should not rerun a full Home aggregate pass when the dashboard is already warm.
    nonisolated static func shouldSkipFullRebuildOnForegroundActivation(
        hasPerformedInitialBuild: Bool,
        carouselSlidesAreDisplayable: Bool,
        hasCarouselHighlights: Bool
    ) -> Bool {
        shouldSkipFullRebuildOnReturn(
            hasPerformedInitialBuild: hasPerformedInitialBuild,
            carouselSlidesAreDisplayable: carouselSlidesAreDisplayable,
            hasCarouselHighlights: hasCarouselHighlights
        )
    }
}
