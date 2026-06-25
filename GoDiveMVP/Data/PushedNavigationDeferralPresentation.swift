import Foundation

/// Defers MapKit / heavy store work until a tab **`NavigationStack`** push animation settles.
enum PushedNavigationDeferralPresentation: Sendable {
    /// Matches trip-detail auto-link deferral and typical UIKit push duration.
    nonisolated static let afterPushDelay: Duration = .milliseconds(300)

    /// MapKit-only deferral — buddy/trip hero chrome mounts on frame one.
    nonisolated static let afterPushMapDeferral: Duration = afterPushDelay
}
