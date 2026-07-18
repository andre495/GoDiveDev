import Foundation

/// Copy for Settings → Delete account.
enum AccountDeletionPresentation: Sendable {
    nonisolated static let buttonTitle = "Delete account"
    nonisolated static let confirmationTitle = "Delete account?"
    nonisolated static let confirmationMessage =
        "This permanently deletes your GoDive profile, dive log, and cloud data for this Apple ID. This cannot be undone."
    nonisolated static let confirmButtonTitle = "Delete account"
    nonisolated static let cancelButtonTitle = "Cancel"
    nonisolated static let appleConfirmTitle = "Confirm with Apple"
    nonisolated static let appleConfirmMessage =
        "Sign in with Apple once more to revoke your Apple credentials and finish deleting your account."
    nonisolated static let progressTitle = "Deleting account…"
    nonisolated static let failedTitle = "Could not delete account"
    nonisolated static let offlineDisabledMessage =
        "Connect to the internet to delete your account."
    nonisolated static let accessibilityIdentifier = "Settings.DeleteAccount"

    /// Account deletion needs network for Firebase / Apple revoke — block when offline.
    nonisolated static func isDeleteAccountEnabled(isConnected: Bool) -> Bool {
        isConnected
    }
}
