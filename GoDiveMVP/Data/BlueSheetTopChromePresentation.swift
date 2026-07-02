import CoreGraphics
import Foundation

/// Top chrome fade tokens for **Home** vs pushed **detail** blue-sheet pages.
enum BlueSheetTopChromePresentation: Sendable {

    /// Home tab root — status-bar scrim + logbook-style fade over the hero band.
    enum HomeHeroFade {
        nonisolated static var usesBrandStatusBarScrim: Bool { true }
        nonisolated static var logbookScrimFeather: CGFloat { 52 }
    }

    /// Pushed detail pages — short status-bar feather only (no full hero-height scrim).
    enum DetailTopFade {
        nonisolated static var usesListStatusBarScrim: Bool { true }
        /// Matches **`AppStatusBarEdgeScrimMetrics.listChromeFeatherHeight`** (22 pt).
        nonisolated static var statusBarFeather: CGFloat { 22 }
    }

    /// Home **`AppHeader`** trailing profile control — ~**20%** larger than the original **48** pt chrome avatar.
    nonisolated static let homeProfileAvatarDiameter: CGFloat = 48 * 1.2
}
