import Foundation

/// Timing policy for work that should not compete with the first interactive frame after launch.
enum AppLaunchPostOverlayPresentation: Sendable {

    /// First Home rebuild starts immediately after root appear (stats-first two-phase paint).
    nonisolated static let initialHomeRebuildDeferNanoseconds: UInt64 = 0

    /// Quiet window after splash dismiss before full Home media enrich (`buildAsync`).
    /// Lifetime stats (Top Species / Top Buddies) already paint on the launch path.
    nonisolated static let postChromeHomeEnrichDeferNanoseconds: UInt64 = 500_000_000

    /// Quiet window before PhotoKit carousel warm (stills + serial video) — swipe/tabs first.
    nonisolated static let postChromeCarouselWarmDeferNanoseconds: UInt64 = 750_000_000

    /// Defer Home marine-life **name map** + dive-site bind until after Home is interactive.
    nonisolated static let postChromeCatalogBindDeferNanoseconds: UInt64 = 2_000_000_000

    /// After warm finishes, wait before persisting missing soft JPEGs (`ensureStoredPreviews`).
    nonisolated static let postChromePreviewPersistDeferNanoseconds: UInt64 = 1_000_000_000

    /// Seconds before heavy launch maintenance (CDN, previews, backfills) runs.
    nonisolated static let deferredMaintenanceDelaySeconds: Double = 2

    /// Fallback MapKit / Google warm when Explore was never opened — after first interactive frame.
    nonisolated static let deferredMapWarmupDelaySeconds: Double = 2.5

    /// Last-resort splash dismiss if Home never marks chrome ready (cancelled rebuild race / hang).
    nonisolated static let homeChromeReadyFailsafeNanoseconds: UInt64 = 8_000_000_000
}
