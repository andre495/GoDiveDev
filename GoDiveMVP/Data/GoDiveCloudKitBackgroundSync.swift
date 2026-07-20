import BackgroundTasks
import Foundation
import os
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Schedules BackgroundTasks so SwiftData private CloudKit mirroring can run while the app is
/// suspended — including over **cellular** (no Wi‑Fi / external-power requirement).
///
/// CloudKit operations already allow cellular by default; these tasks keep the process awake so
/// **`NSPersistentCloudKitContainer`** can export/import. System still throttles opportunistically.
enum GoDiveCloudKitBackgroundSync: Sendable {

    nonisolated static let appRefreshTaskIdentifier = "PrimoSoftware.GoDiveMVP.cloudkit-refresh"
    nonisolated static let processingTaskIdentifier = "PrimoSoftware.GoDiveMVP.cloudkit-processing"

    /// Short opportunistic wake (Background App Refresh).
    nonisolated static let appRefreshEarliestInterval: TimeInterval = 15 * 60
    /// Longer maintenance window for export backlog.
    nonisolated static let processingEarliestInterval: TimeInterval = 45 * 60

    nonisolated static let appRefreshWorkNanoseconds: UInt64 = 25_000_000_000
    nonisolated static let processingWorkNanoseconds: UInt64 = 120_000_000_000

    private nonisolated static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "CloudKitBackgroundSync"
    )

    /// Register task handlers — must run before the app finishes launching.
    @MainActor
    static func registerTasksIfNeeded() {
        guard !GoDiveUITestConfiguration.isActive else { return }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleAppRefresh(refresh)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingTaskIdentifier,
            using: nil
        ) { task in
            guard let processing = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleProcessing(processing)
        }
    }

    /// Submit refresh + processing requests (idempotent — replaces prior pending with same id).
    nonisolated static func scheduleNextOpportunities(
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard shouldSchedule(defaults: defaults) else { return }
        scheduleAppRefresh(earliestBegin: now.addingTimeInterval(appRefreshEarliestInterval))
        scheduleProcessing(earliestBegin: now.addingTimeInterval(processingEarliestInterval))
    }

    nonisolated static func shouldSchedule(defaults: UserDefaults = .standard) -> Bool {
        // Prefer active CloudKit open; also schedule when unset (first launch before open writes the flag).
        if let enabled = defaults.object(forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey) as? Bool {
            return enabled
        }
        return true
    }

    nonisolated static func scheduleAppRefresh(earliestBegin: Date) {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskIdentifier)
        request.earliestBeginDate = earliestBegin
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("BGAppRefresh submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Network required; **no** external power — allows cellular maintenance windows.
    nonisolated static func scheduleProcessing(earliestBegin: Date) {
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.earliestBeginDate = earliestBegin
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("BGProcessing submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Handlers

    private static func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleNextOpportunities()
        let work = Task {
            await performSyncWindow(nanoseconds: appRefreshWorkNanoseconds)
        }
        task.expirationHandler = {
            work.cancel()
        }
        Task {
            _ = await work.result
            task.setTaskCompleted(success: !Task.isCancelled)
        }
    }

    private static func handleProcessing(_ task: BGProcessingTask) {
        scheduleNextOpportunities()
        let work = Task {
            await performSyncWindow(nanoseconds: processingWorkNanoseconds)
        }
        task.expirationHandler = {
            work.cancel()
        }
        Task {
            _ = await work.result
            task.setTaskCompleted(success: !Task.isCancelled)
        }
    }

    /// Loads the production store so CloudKit mirroring is attached, then keeps the process awake
    /// briefly so export/import can progress (including over cellular).
    private static func performSyncWindow(nanoseconds: UInt64) async {
        guard shouldSchedule() else { return }
        AppModelContainer.beginLoadingProductionIfNeeded()
        _ = await AppModelContainer.loadProduction()
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Presentation / test hooks for CloudKit background sync scheduling.
enum GoDiveCloudKitBackgroundSyncPresentation: Sendable {
    nonisolated static var permittedTaskIdentifiers: [String] {
        [
            GoDiveCloudKitBackgroundSync.appRefreshTaskIdentifier,
            GoDiveCloudKitBackgroundSync.processingTaskIdentifier,
        ]
    }

    nonisolated static func processingRequiresExternalPower() -> Bool { false }

    nonisolated static func processingRequiresNetworkConnectivity() -> Bool { true }

    nonisolated static func allowsCellularMaintenanceWindows() -> Bool {
        // requiresExternalPower == false + requiresNetworkConnectivity == true → cellular OK.
        !processingRequiresExternalPower() && processingRequiresNetworkConnectivity()
    }
}
