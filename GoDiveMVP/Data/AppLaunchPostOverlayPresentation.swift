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

    /// Extra wait after chrome before applying launch carousel (0 = seed under splash / apply ASAP).
    /// Media-index fetch starts as soon as launch stats return so it overlaps the splash fade.
    nonisolated static let postChromeLaunchCarouselDeferNanoseconds: UInt64 = 0

    /// Idle Field Guide / Explore full catalog binds after chrome (Home selected).
    /// Opening those tabs binds immediately via **`LazyRootTabPresentation`**.
    nonisolated static let postChromeIdleTabCatalogBindDeferNanoseconds: UInt64 = 1_000_000_000

    /// CloudKit dive-log kick (`fetchCount` / `processPendingChanges`) after chrome ready.
    nonisolated static let postChromeCloudKitKickDeferNanoseconds: UInt64 = 500_000_000

    /// Defer Home marine-life **name map** + dive-site bind until after Home is interactive.
    nonisolated static let postChromeCatalogBindDeferNanoseconds: UInt64 = 2_000_000_000

    /// After warm finishes, wait before persisting missing soft JPEGs (`ensureStoredPreviews`).
    nonisolated static let postChromePreviewPersistDeferNanoseconds: UInt64 = 1_000_000_000

    /// Seconds before heavy launch maintenance (CDN, track backfills — **not** PhotoKit prune) runs.
    nonisolated static let deferredMaintenanceDelaySeconds: Double = 2

    /// Extra quiet window **after Home chrome** before PhotoKit media prune / cloud-id backfill.
    /// Time Profiler showed multi-second Main Thread hangs when prune ran during the first taps.
    nonisolated static let deferredPhotoKitMaintenanceDelaySeconds: Double = 8

    /// Seconds before ~3k-row `dive_sites.json` decode + Explore All Sites session snapshot.
    /// Kept after Home chrome so prewarm does not fight restore / Home `@Query`.
    nonisolated static let deferredDiveSitesPrewarmDelaySeconds: Double = 2.5

    /// Fallback MapKit / Google warm when Explore was never opened — after first interactive frame.
    nonisolated static let deferredMapWarmupDelaySeconds: Double = 2.5

    /// Last-resort splash dismiss if Home never marks chrome ready (cancelled rebuild race / hang).
    nonisolated static let homeChromeReadyFailsafeNanoseconds: UInt64 = 8_000_000_000
}
