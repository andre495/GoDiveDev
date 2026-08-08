import Foundation

/// Console timeline for splash → Home data.
///
/// In Xcode’s debug console or `devicectl … --console`, search **`[LaunchTimeline]`**.
/// DEBUG only — uses **`print`** so lines show even when OSLog levels are filtered.
///
/// Example events: `process_start`, `first_frame`, `splash.container_ready`,
/// `splash.overlay_hidden`, `home.rebuild_applied`.
///
/// MetricKit Organizer TTFF is logged separately as **`[MetricKit.Launch]`** when the system
/// delivers `MXAppLaunchMetric` payloads (often next day; not while a debugger is attached).
enum AppLaunchTimelineLog: Sendable {
    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    /// Process uptime in ms at `process_start` (for first_frame deltas).
    nonisolated(unsafe) private static var processStartUptimeMilliseconds: Int?

    /// Process uptime in ms (compare deltas between lines for cold-launch relative timing).
    nonisolated static func elapsedMilliseconds() -> Int {
        Int(ProcessInfo.processInfo.systemUptime * 1000)
    }

    nonisolated static func event(_ name: String, _ detail: String = "") {
        guard isEnabled else { return }
        let ms = elapsedMilliseconds()
        let line = detail.isEmpty ? "t=\(ms)ms \(name)" : "t=\(ms)ms \(name) \(detail)"
        // Event names + coarse counts only — no UIDs / site names.
        print("[LaunchTimeline] \(line)")
    }

    // MARK: - Process / first frame

    /// Earliest app-entry mark (`GoDiveMVPApp.init`).
    nonisolated static func processStart() {
        processStartUptimeMilliseconds = elapsedMilliseconds()
        event("process_start")
    }

    /// One-shot after the first display refresh (proxy for first screen drawn).
    nonisolated static func firstFrame() {
        let now = elapsedMilliseconds()
        if let start = processStartUptimeMilliseconds {
            event("first_frame", "sinceProcessStartMs=\(now - start)")
        } else {
            event("first_frame")
        }
    }

    // MARK: - Splash

    nonisolated static func splashContainerLoadBegan() {
        event("splash.container_load_begin")
    }

    nonisolated static func splashContainerReady() {
        event("splash.container_ready")
    }

    nonisolated static func splashRestoreBegan(
        waitForCloudKit: Bool,
        storeActivityCount: Int,
        localOwnedActivityCount: Int
    ) {
        event(
            "splash.restore_begin",
            "waitCK=\(waitForCloudKit) storeActivities=\(storeActivityCount) ownedForAppleID=\(localOwnedActivityCount)"
        )
    }

    nonisolated static func splashRestoreEnded(
        attached: Bool,
        ownedDiveCount: Int,
        healedRowCount: Int
    ) {
        event(
            "splash.restore_end",
            "attached=\(attached) ownedDives=\(ownedDiveCount) healedRows=\(healedRowCount)"
        )
    }

    nonisolated static func splashOverlayHidden(
        isRestoringSession: Bool,
        isPopulatingRemoteAccountData: Bool,
        showsMainAppShell: Bool,
        isHomeLaunchChromeReady: Bool = false
    ) {
        event(
            "splash.overlay_hidden",
            "restoring=\(isRestoringSession) populating=\(isPopulatingRemoteAccountData) mainShell=\(showsMainAppShell) homeChrome=\(isHomeLaunchChromeReady)"
        )
    }

    nonisolated static func splashMainShellVisible() {
        event("splash.main_shell_visible")
    }

    // MARK: - Home data

    nonisolated static func homeRootAppear(initialBuild: Bool, ownerDiveQueryCount: Int) {
        event(
            "home.root_appear",
            "initial=\(initialBuild) queryDives=\(ownerDiveQueryCount)"
        )
    }

    nonisolated static func homeRebuildScheduled(source: String, immediate: Bool, queryDives: Int) {
        event(
            "home.rebuild_scheduled",
            "source=\(source) immediate=\(immediate) queryDives=\(queryDives)"
        )
    }

    nonisolated static func homeStatsApplied(queryDives: Int, aggregateDives: Int) {
        event(
            "home.stats_applied",
            "queryDives=\(queryDives) aggregateDives=\(aggregateDives)"
        )
    }

    nonisolated static func homeCarouselPreviewsSeeded(
        queryDives: Int,
        carouselHighlights: Int,
        storedPreviewCount: Int
    ) {
        event(
            "home.carousel_previews_seeded",
            "queryDives=\(queryDives) carousel=\(carouselHighlights) storedPreviews=\(storedPreviewCount)"
        )
    }

    nonisolated static func homeRebuildApplied(
        queryDives: Int,
        aggregateDives: Int,
        carouselHighlights: Int,
        catalogSpecies: Int,
        isInitial: Bool
    ) {
        event(
            "home.rebuild_applied",
            "initial=\(isInitial) queryDives=\(queryDives) aggregateDives=\(aggregateDives) carousel=\(carouselHighlights) catalogSpecies=\(catalogSpecies)"
        )
    }

    nonisolated static func homeOwnerQueryCountChanged(from oldCount: Int, to newCount: Int) {
        event("home.query_dives_changed", "from=\(oldCount) to=\(newCount)")
    }

    nonisolated static func homeOwnershipHealed(rowCount: Int) {
        event("home.ownership_healed", "rows=\(rowCount)")
    }
}
