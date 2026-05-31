import Foundation

/// When the signed-in bootstrap overlay stays up through Home featured-media warm-cache.
enum AppSessionBootstrapPresentation: Sendable {

    /// **`true`** while session restore runs, or signed-in Home carousel media is still warming.
    nonisolated static func showsLaunchOverlay(
        isRestoringSession: Bool,
        isSignedIn: Bool,
        isHomeMediaWarmupComplete: Bool
    ) -> Bool {
        isRestoringSession || (isSignedIn && !isHomeMediaWarmupComplete)
    }
}
