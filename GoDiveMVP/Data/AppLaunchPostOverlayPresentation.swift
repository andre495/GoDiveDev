import Foundation

/// Timing policy for work that should not compete with the first interactive frame after launch.
enum AppLaunchPostOverlayPresentation: Sendable {

    /// Defers the first Home aggregate rebuild so launch maintenance + session reconcile can start first.
    nonisolated static let initialHomeRebuildDeferNanoseconds: UInt64 = 150_000_000

    /// Seconds before heavy launch maintenance (CDN, previews, backfills) runs.
    nonisolated static let deferredMaintenanceDelaySeconds: Double = 2
}
