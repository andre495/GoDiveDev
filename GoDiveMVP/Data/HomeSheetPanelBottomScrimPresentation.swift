import CoreGraphics
import Foundation

/// Layout math for pushed buddy/trip bottom chrome — band bottom pinned to the physical screen edge.
enum HomeSheetPanelBottomScrimPresentation: Sendable {

    /// **`position(y:)`** center for a band whose **bottom** edge sits on the physical screen bottom.
    ///
    /// - **`layoutHeight`**: laid-out stack height from **`GeometryReader`** (above home indicator).
    /// - **`safeAreaBottom`**: home-indicator inset from the same **`GeometryProxy`**.
    nonisolated static func screenBottomAnchoredBandCenterY(
        layoutHeight: CGFloat,
        safeAreaBottom: CGFloat,
        bandHeight: CGFloat
    ) -> CGFloat {
        let screenBottomY = layoutHeight + safeAreaBottom
        return screenBottomY - bandHeight / 2
    }
}
