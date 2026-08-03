import CoreGraphics
import Foundation

/// Fullscreen friend-shared media browser (pinch-zoom photos, streaming video).
enum FriendSharedMediaFullscreenPresentation: Sendable {

    nonisolated static let rootAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.Root"
    nonisolated static let closeAccessibilityIdentifier = "FriendSharedMedia.Fullscreen.Close"

    nonisolated static let minZoomScale: CGFloat = 1
    nonisolated static let maxZoomScale: CGFloat = 4

    nonisolated static func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minZoomScale), maxZoomScale)
    }

    nonisolated static func allowsPanGesture(atZoomScale scale: CGFloat) -> Bool {
        scale > minZoomScale + 0.01
    }

    nonisolated static func pageIndex(
        for mediaID: String?,
        in items: [FriendSharedMediaPresentation.DisplayItem]
    ) -> Int {
        guard let mediaID,
              let index = items.firstIndex(where: { $0.mediaID == mediaID })
        else { return 0 }
        return index
    }

    nonisolated static func chromeTitle(
        pageIndex: Int,
        pageCount: Int
    ) -> String {
        guard pageCount > 0 else { return "" }
        return "\(pageIndex + 1) / \(pageCount)"
    }
}
