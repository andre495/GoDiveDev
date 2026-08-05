import Foundation
import SwiftData

/// Deletes a snorkel from the logbook and removes friend-visible projections.
enum SnorkelActivityDeletion {

    static func delete(
        activityID: UUID,
        container: ModelContainer,
        mainModelContext: ModelContext? = nil,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
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

        try await SnorkelActivityStoreSync.awaitSnorkelAbsent(
            snorkelID: activityID,
            container: container
        )

        if let mainModelContext {
            await MainActor.run {
                mainModelContext.processPendingChanges()
            }
        }

        await emitDeleteProgress(1.0, handler: reportProgress)
        await GoDiveSharedDiveProjectionSync.deleteActivityProjection(activityID: activityID)
        DiveActivityOverviewUIStateStore.removeSnorkel(activityID: activityID)
    }

    static func deletePermanently(
        _ activity: SnorkelActivity,
        modelContext: ModelContext,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        try await delete(
            activityID: activity.id,
            container: modelContext.container,
            mainModelContext: modelContext,
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
