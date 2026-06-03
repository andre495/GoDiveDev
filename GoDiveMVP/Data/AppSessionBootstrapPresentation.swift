import Foundation

/// When the signed-in bootstrap overlay stays up through session restore only (Home media warms on Home).
enum AppSessionBootstrapPresentation: Sendable {

    /// **`true`** while the local session is restoring — not while Home carousel media warms.
    nonisolated static func showsLaunchOverlay(isRestoringSession: Bool) -> Bool {
        isRestoringSession
    }
}
