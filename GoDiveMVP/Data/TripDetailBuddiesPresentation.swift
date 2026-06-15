import CoreGraphics
import Foundation

/// Layout for tagged buddies on the active trip **Buddies** pager page.
enum TripDetailBuddiesPresentation: Sendable {
    nonisolated static let gridColumnCount = 3
    nonisolated static let gridSpacing: CGFloat = 16
    nonisolated static let avatarDiameter: CGFloat = 64
}
