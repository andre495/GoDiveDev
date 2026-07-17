import CoreGraphics
import Foundation

/// Trailing-edge fade for horizontal buddy / marine-life chip rows on the dive overview.
/// Softens the hard clip when more chips exist than fit on screen.
enum DiveActivityHorizontalChipRowScrollFadePresentation: Sendable {

    /// Width of the soft fade band on the trailing edge (pt).
    nonisolated static let fadeWidth: CGFloat = 28

    /// Treat content as overflowing only when it exceeds the viewport by this much.
    nonisolated static let overflowEpsilon: CGFloat = 1

    /// Opacity of the trailing fade (**0…1**) from scroll geometry.
    ///
    /// - **0** when content fits, or when scrolled fully to the trailing edge.
    /// - Ramps to **1** as remaining scroll distance reaches **`fadeWidth`**.
    nonisolated static func trailingFadeOpacity(
        contentWidth: CGFloat,
        containerWidth: CGFloat,
        contentOffsetX: CGFloat
    ) -> CGFloat {
        let maxOffset = max(0, contentWidth - containerWidth)
        guard maxOffset > overflowEpsilon else { return 0 }
        let remaining = max(0, maxOffset - max(0, contentOffsetX))
        guard fadeWidth > 0 else { return remaining > overflowEpsilon ? 1 : 0 }
        return min(1, remaining / fadeWidth)
    }
}
