import Foundation

/// Tiered preload policy for Home featured media (carousel size, startup vs background quality).
enum HomeMediaHighlightWarmupPresentation: Sendable {

    /// How many carousel picks get hero frames + video assets before the launch overlay dismisses.
    nonisolated static let startupFullQualityCount = 2

    /// Low-res poster edge for carousel picks warmed during bootstrap after the first **`startupFullQualityCount`**.
    nonisolated static let previewImageEdge: CGFloat = 480

    enum WarmupQuality: Sendable {
        case preview
        case full
    }

    /// Quality tier for a carousel index during bootstrap (**0**-based).
    nonisolated static func bootstrapQuality(forCarouselIndex index: Int) -> WarmupQuality {
        index < startupFullQualityCount ? .full : .preview
    }

    /// **`true`** when every pick has at least preview coverage and the startup prefix is fully warmed.
    nonisolated static func isBootstrapReady(
        fullReadyCount: Int,
        previewOrFullReadyCount: Int,
        totalCount: Int
    ) -> Bool {
        guard totalCount > 0 else { return true }
        let requiredFull = min(startupFullQualityCount, totalCount)
        guard fullReadyCount >= requiredFull else { return false }
        return previewOrFullReadyCount >= totalCount
    }

    nonisolated static func backgroundFullQualityIndices(totalCount: Int) -> [Int] {
        guard totalCount > startupFullQualityCount else { return [] }
        return Array(startupFullQualityCount ..< totalCount)
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
