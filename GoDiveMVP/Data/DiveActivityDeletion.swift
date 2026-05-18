import SwiftData

/// Removes a **`DiveActivity`** from the store; related **`DiveProfilePoint`** and **`DiveBuddyTag`** rows follow **`@Relationship(deleteRule: .cascade)`** on the model.
enum DiveActivityDeletion {
    /// - **`applySequentialRenumberOverride`:** **`nil`** → use **`AppUserSettings.automaticallyRenumberDives`**; when **`true`**, after delete + save, partial renumber runs on a **background** context.
    /// - **`awaitPostDeleteRenumber`:** **`false`** (default for UI) returns after delete + save and schedules background renumber; **`true`** runs partial renumber on **`modelContext`** and awaits it (tests — same-context **`diveNumber`** reads).
    /// - **Async:** **`await Task.yield()`** at the start so the run loop can paint optimistic UI / modal dismissal before **`save()`**.
    @MainActor
    static func deletePermanently(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        applySequentialRenumberOverride: Bool? = nil,
        awaitPostDeleteRenumber: Bool = false
    ) async throws {
        await Task.yield()

        let deletedStartTime = activity.startTime
        let deletedId = activity.id
        let container = modelContext.container

        let shouldRenumber = applySequentialRenumberOverride ?? AppUserSettings.automaticallyRenumberDives
        let skipRenumber: Bool
        if shouldRenumber {
            let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
            let remaining = all.filter { $0.id != deletedId }
            skipRenumber = DiveActivityDiveNumbering.partialRenumberAfterDeleteWouldBeNoop(
                remaining: remaining,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        } else {
            skipRenumber = true
        }

        modelContext.delete(activity)
        try modelContext.save()

        guard shouldRenumber, !skipRenumber else { return }

        if awaitPostDeleteRenumber {
            await Task.yield()
            try DiveActivityDiveNumbering.renumberDivesNewerThanDeleted(
                deletedStartTime: deletedStartTime,
                deletedId: deletedId,
                modelContext: modelContext
            )
        } else {
            Task {
                await DivePostDeleteRenumberScheduler.shared.scheduleFullRenumber(container: container)
            }
        }
    }
}
