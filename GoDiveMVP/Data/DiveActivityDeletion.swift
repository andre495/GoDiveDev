import Foundation
import SwiftData

/// Deletes a dive from the logbook and optionally tail-renumbers newer dives.
///
/// Deletion runs entirely on a background **`@ModelActor`**. The Logbook hides the row optimistically and must not
/// run a second delete pass on the UI **`ModelContext`** — merging invalidations while **`@Query`** still holds live
/// models can trap with **`EXC_BAD_ACCESS`** (often with no console message).
enum DiveActivityDeletion {

    /// What to delete and whether to renumber dives chronologically newer than the deleted slot.
    struct Request: Sendable {
        let activityID: UUID
        let deletedStartTime: Date
        let deletedId: UUID
        /// When **`true`**, runs tail renumber after the dive is removed (**Settings → Automatically renumber dives**).
        let renumberAfterDelete: Bool
    }

    /// Deletes on a background **`@ModelActor`** context, then renumbers when requested.
    ///
    /// - **`awaitRenumberOnMainContext`:** **`true`** for tests that assert on the same **`ModelContext`** as the UI.
    /// - **`deferRenumber`:** when **`true`** (Logbook UI), tail renumber runs on **`DivePostDeleteRenumberScheduler`** after the progress dialog dismisses.
    static func delete(
        _ request: Request,
        container: ModelContainer,
        awaitRenumberOnMainContext: Bool = false,
        deferRenumber: Bool = false,
        mainModelContext: ModelContext? = nil,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        DiveActivityDeletionDebug.phase(.begin, diveID: request.activityID)

        await emitDeleteProgress(0.12, handler: reportProgress)

        let worker = DiveBackgroundDeletionWorker(modelContainer: container)
        try await worker.deleteDive(id: request.activityID)
        await emitDeleteProgress(0.72, handler: reportProgress)
        DiveActivityDeletionDebug.phase(.afterBackgroundWorker, diveID: request.activityID)

        if request.renumberAfterDelete {
            if awaitRenumberOnMainContext {
                guard let mainModelContext else { return }
                try await MainActor.run {
                    try DiveActivityDiveNumbering.renumberDivesNewerThanDeleted(
                        deletedStartTime: request.deletedStartTime,
                        deletedId: request.deletedId,
                        modelContext: mainModelContext
                    )
                }
            } else if deferRenumber {
                await DivePostDeleteRenumberScheduler.shared.schedulePartialRenumber(
                    container: container,
                    deletedStartTime: request.deletedStartTime,
                    deletedId: request.deletedId
                )
            } else {
                try await DiveActivityPostDeleteRenumbering.renumberAfterDelete(
                    container: container,
                    deletedStartTime: request.deletedStartTime,
                    deletedId: request.deletedId
                )
            }
            await emitDeleteProgress(0.88, handler: reportProgress)
            DiveActivityDeletionDebug.phase(.afterRenumber, diveID: request.activityID)
        }

        DiveActivityDeletionDebug.phase(.succeeded, diveID: request.activityID)
        await emitDeleteProgress(1.0, handler: reportProgress)
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

    // MARK: - Legacy entry points (tests + call sites)

    static func deletePermanently(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        applySequentialRenumberOverride: Bool? = nil,
        awaitPostDeleteRenumber: Bool = false,
        deferRenumber: Bool = false
    ) async throws {
        let renumber = applySequentialRenumberOverride ?? AppUserSettings.automaticallyRenumberDives
        try await delete(
            Request(
                activityID: activity.id,
                deletedStartTime: activity.startTime,
                deletedId: activity.id,
                renumberAfterDelete: renumber
            ),
            container: modelContext.container,
            awaitRenumberOnMainContext: awaitPostDeleteRenumber,
            deferRenumber: deferRenumber,
            mainModelContext: awaitPostDeleteRenumber ? modelContext : nil
        )
    }

    static func deletePermanentlyByID(
        activityID: UUID,
        deletedStartTime: Date,
        deletedId: UUID,
        container: ModelContainer,
        applySequentialRenumberOverride: Bool? = nil,
        awaitPostDeleteRenumber: Bool = false,
        mainModelContext: ModelContext? = nil
    ) async throws {
        let renumber = applySequentialRenumberOverride ?? AppUserSettings.automaticallyRenumberDives
        try await delete(
            Request(
                activityID: activityID,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId,
                renumberAfterDelete: renumber
            ),
            container: container,
            awaitRenumberOnMainContext: awaitPostDeleteRenumber,
            mainModelContext: awaitPostDeleteRenumber ? mainModelContext : nil
        )
    }
}
