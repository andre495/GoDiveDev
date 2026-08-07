import Foundation

/// Process-wide warm All Sites pin snapshot so Explore can paint pins on first select
/// without waiting for an async rebuild (avoids empty-map → recenter flash).
enum ExploreSiteScopeSessionCache: Sendable {
    private nonisolated static let lock = NSLock()
    nonisolated(unsafe) private static var referenceSnapshot: ExploreSiteScopeCache.Snapshot?

    /// Builds the bundled-reference All Sites snapshot (no SwiftData). Call after
    /// **`DiveSiteReferenceCatalog.prewarmBundledReference()`**.
    nonisolated static func prewarmReferenceSnapshot() {
        let snapshot = ExploreSiteScopeCache.make(
            catalog: [],
            userSites: [],
            logbookSiteIDs: []
        )
        // Avoid `Snapshot` Equatable / `.empty` (main-actor-isolated via nested plottable types).
        guard !snapshot.allSitesPlottableSites.isEmpty else { return }
        lock.lock()
        referenceSnapshot = snapshot
        lock.unlock()
    }

    nonisolated static func cachedReferenceSnapshot() -> ExploreSiteScopeCache.Snapshot? {
        lock.lock()
        defer { lock.unlock() }
        return referenceSnapshot
    }

    /// Prefer a fresher rebuild (e.g. with logbook IDs / visited tint) for the next Explore open.
    nonisolated static func storeReferenceSnapshot(_ snapshot: ExploreSiteScopeCache.Snapshot) {
        guard !snapshot.allSitesPlottableSites.isEmpty else { return }
        lock.lock()
        referenceSnapshot = snapshot
        lock.unlock()
    }

    #if DEBUG
    nonisolated static func resetForTesting() {
        lock.lock()
        referenceSnapshot = nil
        lock.unlock()
    }
    #endif
}

/// Whether Explore should refit the camera after a sites update.
enum ExploreCatalogMapCameraFitPresentation: Sendable {
    /// Refit only when the set of site IDs changes (not when only `isVisited` / labels flip).
    nonisolated static func shouldRefitCamera(
        previousSiteIDs: Set<UUID>,
        nextSiteIDs: Set<UUID>
    ) -> Bool {
        previousSiteIDs != nextSiteIDs
    }
}
