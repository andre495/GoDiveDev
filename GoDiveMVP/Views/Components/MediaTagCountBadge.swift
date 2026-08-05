import CoreGraphics
import SwiftUI

/// Shared fish / buddy tag-count chip — forced **circle** (equal frame), matching Home featured media.
enum MediaTagCountBadgePresentation: Sendable {
    nonisolated static let diameter: CGFloat = 18
    nonisolated static let fontSize: CGFloat = 11
    nonisolated static let offsetX: CGFloat = 4
    nonisolated static let offsetY: CGFloat = -4
    /// Grid corner badges sit on a smaller icon; keep the same circle, slightly tighter offset.
    nonisolated static let gridOffsetX: CGFloat = 3
    nonisolated static let gridOffsetY: CGFloat = -3

    /// Layout padding so the Home chrome badge’s offset stays inside the chip bounds (avoids clip).
    nonisolated static var homeOverflowTop: CGFloat { max(0, -offsetY) }
    nonisolated static var homeOverflowTrailing: CGFloat { max(0, offsetX) }

    /// Collapse the fish chip with a clip only while width animates to **0** — clipping while
    /// expanded was cutting the count badge’s top-trailing overhang.
    nonisolated static func clipsHomeChromeChipWhenCollapsed(isCollapsed: Bool) -> Bool {
        isCollapsed
    }
}

/// Notification-style count on media tag icons — always circular (never a stretched capsule).
struct MediaTagCountBadge: View {
    let count: Int
    var offsetX: CGFloat = MediaTagCountBadgePresentation.offsetX
    var offsetY: CGFloat = MediaTagCountBadgePresentation.offsetY

    var body: some View {
        Text("\(count)")
            .font(.system(size: MediaTagCountBadgePresentation.fontSize, weight: .bold))
            .foregroundStyle(.white)
            .monospacedDigit()
            .frame(
                width: MediaTagCountBadgePresentation.diameter,
                height: MediaTagCountBadgePresentation.diameter
            )
            .background {
                Circle()
                    .fill(AppTheme.Colors.accentDeep)
            }
            .offset(x: offsetX, y: offsetY)
            .accessibilityHidden(true)
    }
}
