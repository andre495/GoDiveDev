import CoreGraphics
import Foundation

/// Buddy Feed tile hero paging — media and depth chart / swim map stay on separate pages.
enum LogbookBuddyFeedHeroPagerPresentation: Sendable {
    /// Aspect-fill media / chart layers must not paint into the adjacent page.
    nonisolated static let clipsOverflowingPageContent = true

    /// One page fills the visible hero container (no gap or overlap between pages).
    nonisolated static func pageSize(containerSize: CGSize) -> CGSize {
        CGSize(
            width: max(0, containerSize.width),
            height: max(0, containerSize.height)
        )
    }
}
