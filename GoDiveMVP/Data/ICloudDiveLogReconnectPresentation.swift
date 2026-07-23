import Foundation

/// Copy when Sign in with Apple scheduled a private CloudKit store reopen on the **next** cold launch.
enum ICloudDiveLogReconnectPresentation: Sendable {
    nonisolated static let postSignInAlertTitle = "Loading dive log from iCloud"
    nonisolated static let postSignInAlertMessage =
        "GoDive is connecting to your iCloud dive log. This can take up to a minute on Wi‑Fi."
    nonisolated static let postSignInAlertButtonTitle = "OK"
}
