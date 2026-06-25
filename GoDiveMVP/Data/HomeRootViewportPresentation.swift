import CoreGraphics
import Foundation

/// Keeps Home root hero + stats layout stable while a **`NavigationStack`** push is settling.
enum HomeRootViewportPresentation: Sendable {

    /// While pushed, reuse the last root **`GeometryReader`** height so Home does not relayout under the transition.
    nonisolated static func resolvedViewportHeight(
        geometryHeight: CGFloat,
        isNavigationStackAtRoot: Bool,
        frozenRootViewportHeight: CGFloat?
    ) -> (height: CGFloat, frozenRootViewportHeight: CGFloat?) {
        if isNavigationStackAtRoot {
            return (geometryHeight, geometryHeight)
        }
        if let frozenRootViewportHeight, frozenRootViewportHeight > 0 {
            return (frozenRootViewportHeight, frozenRootViewportHeight)
        }
        return (geometryHeight, nil)
    }
}
