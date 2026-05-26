import Foundation
import SwiftData

/// Deletes a dive from the logbook and optionally tail-renumbers newer dives.
///
/// The progress dialog should stay up until this method returns successfully — it covers:
/// background delete (equipment entries, dive + cascaded profile/buddies/media, orphan site cleanup, video files),
/// optional tail renumber, and main-**`ModelContext`** visibility of the removal.
enum DiveActivityDeletion {

    enum DeletionError: Error, Equatable {
        case diveStillVisibleOnMainContext(UUID)
    }

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
    /// - **`mainModelContext`:** when provided (Logbook), waits until the dive row is gone from the UI context before reporting **`1.0`**.
    static func delete(
        _ request: Request,
        container: ModelContainer,
        awaitRenumberOnMainContext: Bool = false,
        mainModelContext: ModelContext? = nil,
        reportProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws {
        await emitDeleteProgress(0.12, handler: reportProgress)

        let worker = DiveBackgroundDeletionWorker(modelContainer: container)
        try await worker.deleteDive(id: request.activityID)
        await emitDeleteProgress(0.42, handler: reportProgress)

        if request.renumberAfterDelete {
            await emitDeleteProgress(0.58, handler: reportProgress)
            if awaitRenumberOnMainContext {
                guard let mainModelContext else { return }
                try await MainActor.run {
                    try DiveActivityDiveNumbering.renumberDivesNewerThanDeleted(
                        deletedStartTime: request.deletedStartTime,
                        deletedId: request.deletedId,
                        modelContext: mainModelContext
                    )
                }
            } else {
                try await DiveActivityPostDeleteRenumbering.renumberAfterDelete(
                    container: container,
                    deletedStartTime: request.deletedStartTime,
                    deletedId: request.deletedId
                )
            }
            await emitDeleteProgress(0.78, handler: reportProgress)
        }

        if let mainModelContext {
            await emitDeleteProgress(0.88, handler: reportProgress)
            try await waitForDeletionVisibleOnMainContext(
                diveID: request.activityID,
                modelContext: mainModelContext
            )
        }

        await emitDeleteProgress(1.0, handler: reportProgress)
    }

    /// Polls the main **`ModelContext`** until the deleted dive no longer appears (background **`@ModelActor`** save merged).
    @MainActor
    static func waitForDeletionVisibleOnMainContext(
        diveID: UUID,
        modelContext: ModelContext,
        timeoutNanoseconds: UInt64 = 500_000_000,
        pollIntervalNanoseconds: UInt64 = 8_000_000
    ) async throws {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1

        modelContext.processPendingChanges()
        if try modelContext.fetch(descriptor).isEmpty {
            return
        }

        let deadline = Date().addingTimeInterval(Double(timeoutNanoseconds) / 1_000_000_000)
        while Date() < deadline {
            await Task.yield()
            modelContext.processPendingChanges()
            if try modelContext.fetch(descriptor).isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        throw DeletionError.diveStillVisibleOnMainContext(diveID)
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
        awaitPostDeleteRenumber: Bool = false
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
            mainModelContext: modelContext
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
            mainModelContext: mainModelContext
        )
    }
}
