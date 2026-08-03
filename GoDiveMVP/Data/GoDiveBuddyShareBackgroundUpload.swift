import BackgroundTasks
import FirebaseAuth
import Foundation
import os
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Keeps buddy-share Firebase uploads alive in the background and resumes after app kill.
///
/// - **`UIApplication` background task** — extends the current process while uploads run.
/// - **`BGProcessingTask`** — opportunistic wake to drain pending projection upserts + content tiers.
/// - **Launch / foreground resume** — replays disk-backed pending work from **`GoDiveBuddySharePendingWorkStore`**
///   and incomplete rows in **`GoDiveSharedMediaPublishState`**.
enum GoDiveBuddyShareBackgroundUpload: Sendable {
    nonisolated static let processingTaskIdentifier = "PrimoSoftware.GoDiveMVP.buddy-share-upload"
    nonisolated static let processingEarliestInterval: TimeInterval = 5 * 60
    nonisolated static let processingWorkNanoseconds: UInt64 = 120_000_000_000

    private nonisolated static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "BuddyShareBackgroundUpload"
    )

    @MainActor
    private static var backgroundTaskToken: DiveFileImportBackgroundTask.Token?
    @MainActor
    private static var backgroundExecutionDepth = 0

    /// Register BG handler — call from app delegate before finish launching.
    @MainActor
    static func registerTasksIfNeeded() {
        guard !GoDiveUITestConfiguration.isActive else { return }
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

  nonisolated static func scheduleProcessingIfNeeded(now: Date = Date()) {
        guard !GoDiveUITestConfiguration.isActive else { return }
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        request.earliestBeginDate = now.addingTimeInterval(processingEarliestInterval)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("Buddy share BGProcessing submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    static func beginBackgroundExecution() {
        backgroundExecutionDepth += 1
        guard backgroundTaskToken == nil else { return }
        let token = DiveFileImportBackgroundTask.Token()
        token.begin()
        backgroundTaskToken = token
        scheduleProcessingIfNeeded()
    }

    @MainActor
    static func endBackgroundExecutionIfIdle(
        queueHasPendingUpload: Bool,
        publishStateHasPendingContent: Bool,
        diskHasPendingUpsert: Bool
    ) {
        backgroundExecutionDepth = max(0, backgroundExecutionDepth - 1)
        guard backgroundExecutionDepth == 0 else { return }
        guard !queueHasPendingUpload,
              !publishStateHasPendingContent,
              !diskHasPendingUpsert
        else {
            scheduleProcessingIfNeeded()
            return
        }
        backgroundTaskToken?.end()
        backgroundTaskToken = nil
    }

    /// Drain pending buddy-share uploads after launch, foreground, Wi‑Fi reconnect, or BG processing.
    @MainActor
    static func resumePendingWork(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults) else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let ownerUID = Auth.auth().currentUser?.uid, !ownerUID.isEmpty else { return }

        beginBackgroundExecution()

        if GoDiveBuddySharePendingWorkStore.isFullRepublishPending(ownerProfileID: ownerProfileID) {
            await GoDiveSharedDiveProjectionSync.republishAllOwnedDives(
                ownerProfileID: ownerProfileID,
                modelContext: modelContext,
                userDefaults: userDefaults
            )
            GoDiveBuddySharePendingWorkStore.clearFullRepublishPending(ownerProfileID: ownerProfileID)
        }

        var activityIDs = GoDiveBuddySharePendingWorkStore.pendingUpsertActivityIDs(
            ownerProfileID: ownerProfileID
        )
        for activityID in GoDiveSharedMediaPublishState.allActivityIDs(ownerUID: ownerUID) {
            let record = GoDiveSharedMediaPublishState.loadActivityRecord(
                ownerUID: ownerUID,
                activityID: activityID
            )
            if GoDiveSharedMediaPublishState.hasIncompleteContentItems(in: record) {
                activityIDs.insert(activityID)
            }
        }

        if !activityIDs.isEmpty {
            var completedUpserts: Set<UUID> = []

            let dives = (try? modelContext.fetch(FetchDescriptor<DiveActivity>()))?
                .filter { $0.ownerProfileID == ownerProfileID && activityIDs.contains($0.id) } ?? []
            for dive in dives {
                await GoDiveSharedDiveProjectionSync.upsertDive(
                    dive,
                    ownerUID: ownerUID,
                    modelContext: modelContext
                )
                completedUpserts.insert(dive.id)
                await GoDiveSharedMediaUpload.resumeIncompleteContentPhase(
                    ownerUID: ownerUID,
                    activityID: dive.id,
                    userDefaults: userDefaults
                )
            }

            let snorkels = (try? modelContext.fetch(FetchDescriptor<SnorkelActivity>()))?
                .filter { $0.ownerProfileID == ownerProfileID && activityIDs.contains($0.id) } ?? []
            for snorkel in snorkels {
                await GoDiveSharedDiveProjectionSync.upsertSnorkel(
                    snorkel,
                    ownerUID: ownerUID,
                    modelContext: modelContext
                )
                completedUpserts.insert(snorkel.id)
                await GoDiveSharedMediaUpload.resumeIncompleteContentPhase(
                    ownerUID: ownerUID,
                    activityID: snorkel.id,
                    userDefaults: userDefaults
                )
            }

            GoDiveBuddySharePendingWorkStore.clearPendingUpserts(
                ownerProfileID: ownerProfileID,
                activityIDs: completedUpserts
            )
        }

        await refreshBackgroundExecutionIdleState(
            ownerProfileID: ownerProfileID,
            ownerUID: ownerUID
        )
    }

    @MainActor
    static func refreshBackgroundExecutionIdleState(
        ownerProfileID: UUID,
        ownerUID: String
    ) async {
        let queuePending = await GoDiveSharedMediaUploadQueue.shared.hasAnyPendingUpload()
        let publishPending = GoDiveSharedMediaPublishState.allActivityIDs(ownerUID: ownerUID).contains {
            GoDiveSharedMediaPublishState.hasIncompleteContentItems(
                in: GoDiveSharedMediaPublishState.loadActivityRecord(
                    ownerUID: ownerUID,
                    activityID: $0
                )
            )
        }
        let diskPending = !GoDiveBuddySharePendingWorkStore.pendingUpsertActivityIDs(
            ownerProfileID: ownerProfileID
        ).isEmpty
            || GoDiveBuddySharePendingWorkStore.isFullRepublishPending(ownerProfileID: ownerProfileID)

        endBackgroundExecutionIfIdle(
            queueHasPendingUpload: queuePending,
            publishStateHasPendingContent: publishPending,
            diskHasPendingUpsert: diskPending
        )
    }

    // MARK: - BGProcessing

    private static func handleProcessing(_ task: BGProcessingTask) {
        scheduleProcessingIfNeeded()
        let work = Task {
            await performUploadWindow()
        }
        task.expirationHandler = {
            work.cancel()
        }
        Task {
            let result = await work.result
            let succeeded: Bool
            if case .success = result {
                succeeded = true
            } else {
                succeeded = false
            }
            task.setTaskCompleted(success: succeeded)
        }
    }

    private static func performUploadWindow() async {
        AppModelContainer.beginLoadingProductionIfNeeded()
        let container = await AppModelContainer.loadProduction()
        let context = ModelContext(container)
        context.autosaveEnabled = true
        guard let profileID = AppLaunchSessionRestorePresentation.loadPersistedProfileID() else { return }
        await runResumeOnMainActor(profileID: profileID, modelContext: context)
        try? await Task.sleep(nanoseconds: processingWorkNanoseconds)
    }

    @MainActor
    private static func runResumeOnMainActor(
        profileID: UUID,
        modelContext: ModelContext
    ) async {
        await resumePendingWork(ownerProfileID: profileID, modelContext: modelContext)
    }
}

/// Presentation / test hooks for buddy-share background upload scheduling.
enum GoDiveBuddyShareBackgroundUploadPresentation: Sendable {
    nonisolated static var permittedTaskIdentifiers: [String] {
        [GoDiveBuddyShareBackgroundUpload.processingTaskIdentifier]
    }

    nonisolated static func processingRequiresExternalPower() -> Bool { false }

    nonisolated static func processingRequiresNetworkConnectivity() -> Bool { true }
}
