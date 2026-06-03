import Foundation

/// Tiered preload policy for Home featured media (carousel size, startup vs background quality).
enum HomeMediaHighlightWarmupPresentation: Sendable {

    /// How many carousel picks get hero frames before background warm (slide **0** only at startup).
    nonisolated static let startupFullQualityCount = 1

    /// Typical Home hero width when warming before layout (points).
    nonisolated static let defaultHeroContainerWidth: CGFloat = 390

    /// Hero decode scale — **2×** keeps full-bleed sharp without decoding at **3×** / 1200px.
    nonisolated static let heroScaleFactor: CGFloat = 2

    /// Cap for PhotoKit hero **`targetSize`** edge (points × scale).
    nonisolated static let maxHeroImageEdge: CGFloat = 900

    /// Seconds to defer warming slides **1…n** so launch + first frame stay responsive.
    nonisolated static let deferredCarouselWarmDelaySeconds: Double = 1.5

    /// Low-res poster edge for carousel picks warmed during bootstrap after the first **`startupFullQualityCount`**.
    nonisolated static let previewImageEdge: CGFloat = 480

    /// Max seconds the launch overlay waits for Home media before revealing the tab (warm continues on Home).
    nonisolated static let bootstrapOverlayMaxWaitSeconds: Double = 5

    enum WarmupQuality: Sendable {
        case preview
        case full
    }

    /// Quality tier for a carousel index during bootstrap (**0**-based).
    nonisolated static func bootstrapQuality(forCarouselIndex index: Int) -> WarmupQuality {
        index < startupFullQualityCount ? .full : .preview
    }

    /// **`true`** when the startup prefix (slide **0**) has a full hero poster.
    nonisolated static func isBootstrapReady(
        fullReadyCount: Int,
        previewOrFullReadyCount: Int,
        totalCount: Int
    ) -> Bool {
        guard totalCount > 0 else { return true }
        let requiredFull = min(startupFullQualityCount, totalCount)
        return fullReadyCount >= requiredFull
    }

    nonisolated static func backgroundFullQualityIndices(totalCount: Int) -> [Int] {
        guard totalCount > startupFullQualityCount else { return [] }
        return Array(startupFullQualityCount ..< totalCount)
    }

    /// PhotoKit hero edge for a given container width (defaults to **`defaultHeroContainerWidth`**).
    nonisolated static func heroImageEdge(containerWidth: CGFloat = defaultHeroContainerWidth) -> CGFloat {
        let scaled = containerWidth * heroScaleFactor
        return min(max(scaled, previewImageEdge + 1), maxHeroImageEdge)
    }

    /// **`true`** when the launch overlay can dismiss — full bootstrap **or** first slide has a poster frame.
    nonisolated static func isOverlayDismissReady(
        isBootstrapReady: Bool,
        firstSlideHasDisplayableImage: Bool
    ) -> Bool {
        isBootstrapReady || firstSlideHasDisplayableImage
    }
}

extension HomeMediaHighlightWarmupPresentation.WarmupQuality: Equatable {
    /// Explicit **nonisolated** **`==`** keeps Swift Testing **`#expect`** usable in Swift 6.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.preview, .preview), (.full, .full):
            return true
        default:
            return false
        }
    }
}
