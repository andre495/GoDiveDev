import Foundation
import SwiftData

/// Deletes a snorkel from the logbook and removes friend-visible projections.
///
/// Deletion runs entirely on a background **`@ModelActor`**. The Logbook must not run a second delete
/// pass on the UI **`ModelContext`** — merging invalidations while **`@Query`** still holds live models
/// can trap with **`EXC_BAD_ACCESS`** (often with no console message).
enum SnorkelActivityDeletion {

    /// Deletes on a background **`@ModelActor`** context, then drops friend-share projections.
    static func delete(
        activityID: UUID,
        container: ModelContainer,
        mainModelContext: ModelContext? = nil,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        SnorkelActivityDeletionDebug.began(snorkelID: activityID)
        await emitDeleteProgress(0.12, handler: reportProgress)

        let sightingUUIDs = await OntologyGraphActivityCleanup.sightingUUIDs(
            snorkelActivityID: activityID,
            container: container
        )

        let worker = SnorkelBackgroundDeletionWorker(modelContainer: container)
        try await worker.deleteSnorkel(id: activityID)
        await emitDeleteProgress(0.72, handler: reportProgress)

        await OntologyGraphActivityCleanup.markCommunityContributionsDeleted(
            activityUUID: activityID,
            sightingUUIDs: sightingUUIDs
        )

        do {
            try await SnorkelActivityStoreSync.awaitSnorkelAbsent(
                snorkelID: activityID,
                container: container
            )
        } catch {
            SnorkelActivityDeletionDebug.failure(
                snorkelID: activityID,
                error: error,
                contextLabel: "store-sync"
            )
            if let mainModelContext {
                SnorkelActivityDeletionDebug.snapshot(
                    snorkelID: activityID,
                    contextLabel: "store-sync",
                    modelContext: mainModelContext
                )
            }
            throw error
        }

        if let mainModelContext {
            await MainActor.run {
                mainModelContext.processPendingChanges()
            }
        }

        SnorkelActivityDeletionDebug.succeeded(snorkelID: activityID)
        await emitDeleteProgress(1.0, handler: reportProgress)
        await GoDiveSharedDiveProjectionSync.deleteActivityProjection(activityID: activityID)
        DiveActivityOverviewUIStateStore.removeSnorkel(activityID: activityID)
    }

    static func deletePermanently(
        _ activity: SnorkelActivity,
        modelContext: ModelContext,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        let activityID = activity.id
        try await delete(
            activityID: activityID,
            container: modelContext.container,
            mainModelContext: modelContext,
            reportProgress: reportProgress
        )
    }

    static func deletePermanentlyByID(
        activityID: UUID,
        container: ModelContainer,
        mainModelContext: ModelContext? = nil,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        try await delete(
            activityID: activityID,
            container: container,
            mainModelContext: mainModelContext,
            reportProgress: reportProgress
        )
    }

    private static func emitDeleteProgress(
        _ value: Double,
        handler: (@MainActor @Sendable (Double) -> Void)?
    ) async {
        guard let handler else { return }
        await MainActor.run {
            handler(value)
        }
    }
}
