import CoreGraphics
import Foundation

/// Shared 3-column still preview grid for buddy tagged media and trip linked media.
enum LinkedMediaGridPresentation: Sendable {

    nonisolated static let columnCount = 3
    nonisolated static let spacing: CGFloat = AppTheme.Spacing.sm
    nonisolated static let cornerRadius: CGFloat = DiveActivityMediaPresentation.carouselThumbnailCornerRadius

    nonisolated static func cellSideLength(containerWidth: CGFloat) -> CGFloat {
        let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
        let availableWidth = max(containerWidth - totalSpacing, 1)
        return max(availableWidth / CGFloat(columnCount), 1)
    }
}
