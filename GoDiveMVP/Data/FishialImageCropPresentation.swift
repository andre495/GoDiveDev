import CoreGraphics
import Foundation

/// Copy and layout helpers for the Fishial still crop step.
enum FishialImageCropPresentation: Sendable {
    nonisolated static let photoInstruction =
        "Pinch and drag to frame the fish, then tap Identify."
    nonisolated static let exportedStillInstruction =
        "Pinch and drag to frame the fish, then tap Identify."
    nonisolated static let videoScrubInstruction =
        "Scrub to the clearest view of the fish, then tap Continue."

    /// Square crop viewport that fits inside the editor container.
    nonisolated static func squareCropViewportSize(
        in containerSize: CGSize,
        horizontalPadding: CGFloat = 0,
        verticalPadding: CGFloat = 0
    ) -> CGSize {
        let availableWidth = max(containerSize.width - (horizontalPadding * 2), 1)
        let availableHeight = max(containerSize.height - (verticalPadding * 2), 1)
        let side = min(availableWidth, availableHeight)
        return CGSize(width: side, height: side)
    }
}
