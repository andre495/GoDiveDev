import Foundation
import SwiftData

/// Removes a **`DiveActivity`** from the store; related **`DiveProfilePoint`**, **`DiveBuddyTag`**, and **`DiveMediaPhoto`** rows follow **`@Relationship(deleteRule: .cascade)`** on the model.
enum DiveActivityDeletion {
    /// - **`applySequentialRenumberOverride`:** **`nil`** → use **`AppUserSettings.automaticallyRenumberDives`**; when **`true`**, schedules or awaits background renumber after delete.
    /// - **`awaitPostDeleteRenumber`:** **`false`** (default for UI) returns after background delete + save and schedules background renumber; **`true`** awaits partial renumber on the **main** **`ModelContext`** (tests).
    /// - Delete + **`save()`** run on **`DiveBackgroundDeletionWorker`** (**`@ModelActor`**) so cascade removal of profile points does not block Logbook.
    static func deletePermanently(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        applySequentialRenumberOverride: Bool? = nil,
        awaitPostDeleteRenumber: Bool = false
    ) async throws {
        try await deletePermanentlyByID(
            activityID: activity.id,
            deletedStartTime: activity.startTime,
            deletedId: activity.id,
            container: modelContext.container,
            applySequentialRenumberOverride: applySequentialRenumberOverride,
            awaitPostDeleteRenumber: awaitPostDeleteRenumber,
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
        await Task.yield()

        let shouldRenumber = applySequentialRenumberOverride ?? AppUserSettings.automaticallyRenumberDives
        let worker = DiveBackgroundDeletionWorker(modelContainer: container)
        let skipPostDeleteRenumber = try await worker.deleteDive(
            id: activityID,
            deletedStartTime: deletedStartTime,
            deletedId: deletedId,
            shouldCheckRenumber: shouldRenumber
        )

        guard shouldRenumber, !skipPostDeleteRenumber else { return }

        if awaitPostDeleteRenumber {
            await Task.yield()
            guard let mainModelContext else { return }
            try await MainActor.run {
                try DiveActivityDiveNumbering.renumberDivesNewerThanDeleted(
                    deletedStartTime: deletedStartTime,
                    deletedId: deletedId,
                    modelContext: mainModelContext
                )
            }
        } else {
            await DivePostDeleteRenumberScheduler.shared.schedulePartialRenumber(
                container: container,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        }
    }
}
