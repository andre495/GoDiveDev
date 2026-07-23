import Foundation

/// When the signed-in bootstrap overlay stays up through session restore only (Home media warms on Home).
enum AppSessionBootstrapPresentation: Sendable {

    /// **`true`** while the local session is restoring or loading Firebase / iCloud account data.
    nonisolated static func showsLaunchOverlay(
        isRestoringSession: Bool,
        isPopulatingRemoteAccountData: Bool
    ) -> Bool {
        isRestoringSession || isPopulatingRemoteAccountData
    }
}
