import CoreGraphics
import Foundation

/// Shared 3-column still preview grid for buddy tagged media and trip linked media.
enum LinkedMediaGridPresentation: Sendable {

    nonisolated static let columnCount = 3
    nonisolated static let spacing: CGFloat = AppTheme.Spacing.sm
    nonisolated static let cornerRadius: CGFloat = DiveActivityMediaPresentation.carouselThumbnailCornerRadius

    /// Point size used when grid cells pass **`size: 0`**; PhotoKit target is **`photoKitRequestEdge`**.
    /// Slightly above a soft **256 px** JPEG so visible cells can sharpen without full-hero fetches.
    nonisolated static let gridThumbnailPointSize: CGFloat = 180
    /// Retina-ish pixel edge for grid PhotoKit stills (**`pointSize × 2`** ≈ **360**).
    nonisolated static var photoKitRequestEdge: CGFloat {
        max(gridThumbnailPointSize * 2, 1)
    }
    nonisolated static let tagIconPointSize: CGFloat = 11
    nonisolated static let tagIconPadding: CGFloat = 4
    nonisolated static let tagIconEdgePadding: CGFloat = 6
    /// Cells are square (`aspectRatio` 1); images use `scaledToFill` inside the square clip.
    nonisolated static let cellAspectRatio: CGFloat = 1

    nonisolated static func cellSideLength(containerWidth: CGFloat) -> CGFloat {
        let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
        let availableWidth = max(containerWidth - totalSpacing, 1)
        return max(availableWidth / CGFloat(columnCount), 1)
    }

    /// Corner fish / buddy icons only when that media has tags of that kind.
    nonisolated static func showsTagIcon(hasTags: Bool) -> Bool {
        hasTags
    }

    /// Count capsule when there is more than one tag (Home carousel style).
    nonisolated static func showsTagCountBadge(tagCount: Int) -> Bool {
        tagCount > 1
    }

    /// Fish badge → marine-life overview; buddy badge → buddies overview (dive Media **large** sheet).
    nonisolated static func tagOverviewMode(isBuddyBadge: Bool) -> DiveActivityMediaLargeDetentMode {
        isBuddyBadge ? .buddies : .marineLife
    }
}
