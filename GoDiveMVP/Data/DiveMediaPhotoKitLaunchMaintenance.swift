import Foundation
import SwiftData
import os

/// PhotoKit media prune + cloud-identifier backfill after Home is interactive.
///
/// Kept off the early post-chrome window (and off MainActor identity reconcile) because Time Profiler
/// showed multi-second hangs from `PHAsset.fetchAssets` during the first taps.
///
/// All entry points are **`nonisolated`** so default MainActor isolation cannot pull prune work
/// back onto the UI thread from `Task.detached`.
enum DiveMediaPhotoKitLaunchMaintenance: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "PhotoKitLaunchMaintenance"
    )

    /// Latch storage — cleared from a detached task defer.
    nonisolated private static let scheduledTaskSlot =
        OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    /// Coalesced schedule — safe to call from launch maintenance and CloudKit identity reconcile.
    /// While a run is pending/in-flight, further schedules no-op; the latch clears when finished so a
    /// later CloudKit import can prune again.
    nonisolated static func schedule(container: ModelContainer) {
        let shouldStart = scheduledTaskSlot.withLock { slot -> Bool in
            if slot != nil { return false }
            slot = Task.detached(priority: .utility) {
                defer {
                    scheduledTaskSlot.withLock { $0 = nil }
                }
                await runWhenQuiet(container: container)
            }
            return true
        }
        _ = shouldStart
    }

    /// Wait for Home chrome (or failsafe), then an extra quiet window, then prune/backfill on a
    /// background **`ModelContext`**.
    nonisolated private static func runWhenQuiet(container: ModelContainer) async {
        await waitForHomeChromeOrTimeout()
        let delay = AppLaunchPostOverlayPresentation.deferredPhotoKitMaintenanceDelaySeconds
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }
        guard !Task.isCancelled else { return }
        await perform(container: container)
    }

    nonisolated private static func waitForHomeChromeOrTimeout() async {
        let pollMs: UInt64 = 250
        let failsafeNs = AppLaunchPostOverlayPresentation.homeChromeReadyFailsafeNanoseconds
        let maxPolls = max(Int(failsafeNs / (pollMs * 1_000_000)), 1)
        for _ in 0..<maxPolls {
            guard !Task.isCancelled else { return }
            let ready = await MainActor.run {
                AccountSession.shared.isHomeLaunchChromeReady
            }
            if ready { return }
            try? await Task.sleep(for: .milliseconds(pollMs))
        }
    }

    nonisolated private static func perform(container: ModelContainer) async {
        let context = ModelContext(container)
        context.autosaveEnabled = true
        #if canImport(Photos)
        DiveMediaCloudIdentifierBackfill.backfillIfNeeded(modelContext: context)
        let pruned = DiveMediaReferencePruning.pruneMissingLibraryAssets(modelContext: context)
        log.notice("photoKit_maintenance pruned=\(pruned)")
        #else
        _ = context
        #endif
    }

    #if DEBUG
    /// Test seam — clears the coalesced schedule latch.
    nonisolated static func resetScheduleLatchForTesting() {
        scheduledTaskSlot.withLock { slot in
            slot?.cancel()
            slot = nil
        }
    }
    #endif
}
