import SwiftUI

/// Apple OK emoji (👌) as a solid tinted silhouette for Buddy Feed likes.
/// Uses the system emoji glyph as a mask so the shape matches Apple’s emoji exactly.
struct BuddyFeedOkayHandIcon: View {
    var isLiked: Bool
    var size: CGFloat = LogbookBuddyFeedTileLayout.actionBarIconSize

    private var fillColor: Color {
        isLiked
            ? AppTheme.Colors.accent
            : AppTheme.Colors.secondaryText.opacity(0.55)
    }

    var body: some View {
        fillColor
            .frame(width: size, height: size)
            .mask {
                Text(LogbookBuddyFeedPresentation.likeEmoji)
                    .font(.system(size: size))
                    .minimumScaleFactor(1)
            }
            .scaleEffect(isLiked ? 1.12 : 1)
            .accessibilityHidden(true)
    }
}
