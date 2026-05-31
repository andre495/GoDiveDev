import Foundation

/// Auto-advance rules for the Home featured-media carousel.
enum HomeMediaCarouselPresentation: Sendable {

    /// How long a photo slide stays visible before advancing.
    nonisolated static let photoDisplaySeconds: TimeInterval = 10

    /// Next slide index; wraps from last → first.
    nonisolated static func nextIndex(after current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    nonisolated static func shouldAutoAdvance(slideCount: Int) -> Bool {
        slideCount > 1
    }
}
