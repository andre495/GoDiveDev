import Foundation

/// Selection / launch gates for idle root-tab catalog binds (SwiftData → UI arrays).
///
/// Catalogs are **local** (bundled seed + SwiftData catalog store; CDN is a deferred
/// version/checksum check in **`CatalogCDNRefresh`**). Idle Field Guide / Explore binds
/// wait until Home chrome is ready plus a quiet window so MainActor bind work does not
/// race the first interactive taps. Opening the tab binds immediately.
///
/// Do **not** swap a whole tab for `Color.clear` — iOS 26 `TabView` can freeze that
/// placeholder after the first tab change.
enum LazyRootTabPresentation: Sendable {

    nonisolated enum CatalogBindStart: Equatable, Sendable {
        /// Tab is selected — bind now (do not wait on Home chrome).
        case immediate
        /// Home chrome ready and tab idle — sleep quiet window then bind.
        case afterChromeQuietWindow
        /// Splash / Gate 3 still up — poll until chrome ready or tab selected.
        case waitUntilChromeOrSelected
    }

    /// When Field Guide / Explore may start a catalog bind relative to Home launch.
    nonisolated static func catalogBindStart(
        isTabSelected: Bool,
        isHomeLaunchChromeReady: Bool
    ) -> CatalogBindStart {
        if isTabSelected { return .immediate }
        if isHomeLaunchChromeReady { return .afterChromeQuietWindow }
        return .waitUntilChromeOrSelected
    }

    /// Fetch/bind again only when not yet finished (or explicit force). Empty catalogs
    /// still count as loaded — otherwise every tab visit re-scans SwiftData forever.
    nonisolated static func shouldFetchCatalog(
        hasLoadedCatalog: Bool,
        force: Bool = false
    ) -> Bool {
        force || !hasLoadedCatalog
    }

    /// One deferred retry after an empty first bind (launch seed may still be writing).
    nonisolated static let emptyCatalogRetryNanoseconds: UInt64 = 2_000_000_000

    /// Poll interval while waiting for Home chrome or tab selection.
    nonisolated static let catalogBindPollNanoseconds: UInt64 = 50_000_000

    /// Wait until catalog bind is allowed (selected, or chrome ready + quiet window).
    @MainActor
    static func waitUntilCatalogBindAllowed(
        isTabSelected: @MainActor () -> Bool,
        isHomeLaunchChromeReady: @MainActor () -> Bool,
        quietWindowNanoseconds: UInt64 = AppLaunchPostOverlayPresentation
            .postChromeIdleTabCatalogBindDeferNanoseconds,
        pollNanoseconds: UInt64 = catalogBindPollNanoseconds
    ) async {
        while !Task.isCancelled {
            switch catalogBindStart(
                isTabSelected: isTabSelected(),
                isHomeLaunchChromeReady: isHomeLaunchChromeReady()
            ) {
            case .immediate:
                return
            case .afterChromeQuietWindow:
                var remaining = quietWindowNanoseconds
                while remaining > 0, !Task.isCancelled {
                    if isTabSelected() { return }
                    let step = min(pollNanoseconds, remaining)
                    try? await Task.sleep(nanoseconds: step)
                    remaining -= step
                }
                return
            case .waitUntilChromeOrSelected:
                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }
        }
    }
}
