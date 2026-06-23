import CoreGraphics
import Foundation

/// Layout for tagged buddies on the active trip **Buddies** pager page.
enum TripDetailBuddiesPresentation: Sendable {
    nonisolated static let gridColumnCount = 3
    nonisolated static let gridSpacing: CGFloat = 16
    nonisolated static let avatarDiameter: CGFloat = 64
    nonisolated static let nameLineLimit = 2
    nonisolated static let subtitleLineLimit = 2
    /// Minimum caption block height (two footnote lines) so avatars stay aligned when names wrap unevenly.
    nonisolated static let gridCaptionMinHeight: CGFloat = 34
}
