import SwiftData

/// Removes a **`DiveActivity`** from the store; related **`DiveProfilePoint`** and **`DiveBuddyTag`** rows follow **`@Relationship(deleteRule: .cascade)`** on the model.
enum DiveActivityDeletion {
    /// - **`applySequentialRenumberOverride`:** **`nil`** → use **`AppUserSettings.automaticallyRenumberDives`**; when **`true`**, after delete + save, **`DiveActivityDiveNumbering.renumberAllChronologically`** runs.
    /// - **`awaitPostDeleteRenumber`:** **`false`** (default for UI) schedules renumber on a separate main-actor task so **`deletePermanently`** returns after delete + save; **`true`** awaits renumber (tests).
    /// - **Async:** **`await Task.yield()`** at the start so the run loop can paint optimistic UI / modal dismissal before **`save()`**.
    @MainActor
    static func deletePermanently(
        _ activity: DiveActivity,
        modelContext: ModelContext,
        applySequentialRenumberOverride: Bool? = nil,
        awaitPostDeleteRenumber: Bool = false
    ) async throws {
        await Task.yield()
        modelContext.delete(activity)
        try modelContext.save()

        let renumber = applySequentialRenumberOverride ?? AppUserSettings.automaticallyRenumberDives
        guard renumber else { return }

        if awaitPostDeleteRenumber {
            await Task.yield()
            try DiveActivityDiveNumbering.renumberAllChronologically(modelContext: modelContext)
        } else {
            Task(priority: .utility) { @MainActor in
                await Task.yield()
                try? DiveActivityDiveNumbering.renumberAllChronologically(modelContext: modelContext)
            }
        }
    }
}
