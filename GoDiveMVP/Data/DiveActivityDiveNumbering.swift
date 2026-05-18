import Foundation
import SwiftData

/// Persists **`DiveActivity.diveNumber`** so Logbook and single-dive screens stay aligned.
///
/// **Rules**
/// - **`.fit` import:** **`assignNextDiveNumberChainedAfterNewest`** — next **#** is **(last numbered dive in **`startTime`** order) + 1**; dives with **`diveNumber == nil`** (unset or **`diveNumberExplicitlyNone`**) do not advance the chain. Garmin **`SessionMesg`** is not used.
/// - **After delete (when automatic renumber is on in Settings):** **`DiveBackgroundRenumberingWorker`** (**`@ModelActor`**) persists **#**s off the main actor; Logbook labels use chronological display. **`renumberAllChronologically`** on the main context is for Settings / import. **`partialRenumberAfterDeleteWouldBeNoop`** skips work when tail **#**s are already correct.
/// - **JSON fixtures / mapper:** **`diveNumber`** from the DTO when present; **`backfillMissingDiveNumbers`** fills **`nil`** only when **`diveNumberExplicitlyNone`** is **`false`**.
enum DiveActivityDiveNumbering {
    /// Oldest **`startTime`** → **1**; ties broken by **`id`**.
    nonisolated static func sequentialIndicesById(for activities: [DiveActivity]) -> [UUID: Int] {
        guard !activities.isEmpty else { return [:] }
        let sorted = activities.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        return Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($0.element.id, $0.offset + 1) })
    }

    /// **`a`** is strictly before **`(deletedStartTime, deletedId)`** in chronological order (same tie-break as **`sequentialIndicesById`**).
    nonisolated static func chronologicallyBefore(
        _ a: DiveActivity,
        deletedStartTime: Date,
        deletedId: UUID
    ) -> Bool {
        if a.startTime != deletedStartTime {
            return a.startTime < deletedStartTime
        }
        return a.id.uuidString < deletedId.uuidString
    }

    /// **`true`** when renumbering **only** dives after the deleted slot would not write any row (skip **Renumber dives?**).
    nonisolated static func partialRenumberAfterDeleteWouldBeNoop(
        remaining: [DiveActivity],
        deletedStartTime: Date,
        deletedId: UUID
    ) -> Bool {
        guard !remaining.isEmpty else { return true }
        let older = remaining.filter { chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let newer = remaining.filter { !chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let base = older.compactMap(\.diveNumber).max() ?? 0
        let newerSorted = newer.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        for (i, a) in newerSorted.enumerated() {
            let expected = base + 1 + i
            if a.diveNumberExplicitlyNone || a.diveNumber != expected {
                return false
            }
        }
        return true
    }

    /// Next **`.fit`** **#** = **(last non-**`nil`** **`diveNumber`** in **`startTime`** order) + 1**, or **1** if none. Dives with no number (unset or explicit none) do not advance the chain. Sets **`diveNumberExplicitlyNone`** to **`false`**.
    nonisolated static func nextChainedDiveNumberForNewImport(existingDives: [DiveActivity]) -> Int {
        guard !existingDives.isEmpty else { return 1 }
        let sorted = existingDives.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var lastNumbered: Int?
        for a in sorted {
            if let n = a.diveNumber {
                lastNumbered = n
            }
        }
        return (lastNumbered ?? 0) + 1
    }

    @MainActor
    static func assignNextDiveNumberChainedAfterNewest(for activity: DiveActivity, modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        activity.diveNumber = nextChainedDiveNumberForNewImport(existingDives: existing)
        activity.diveNumberExplicitlyNone = false
    }

    /// Rewrites **`diveNumber`** on **every** persisted dive to **1…n** in **`startTime`** order (ties **`id`**). Main-context only; background delete uses **`DiveBackgroundRenumberingWorker`**.
    @MainActor
    static func renumberAllChronologically(modelContext: ModelContext) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        guard !all.isEmpty else { return }
        let map = sequentialIndicesById(for: all)
        var changed = false
        for a in all {
            let next = map[a.id]
            let needsWrite = a.diveNumberExplicitlyNone || a.diveNumber != next
            if needsWrite {
                a.diveNumberExplicitlyNone = false
                a.diveNumber = next
                changed = true
            }
        }
        if changed {
            try modelContext.save()
        }
    }

    @MainActor
    static func applyAutomaticSequentialRenumberIfNeeded(modelContext: ModelContext) throws {
        guard AppUserSettings.automaticallyRenumberDives else { return }
        try renumberAllChronologically(modelContext: modelContext)
    }

    /// Renumbers only dives **strictly after** **`(deletedStartTime, deletedId)`** in chronological order: **`base + 1`**, **`base + 2`**, … where **`base`** = **`max(diveNumber)`** among older dives (or **0**). Older dives are untouched. Main-context only; background delete uses **`DiveBackgroundRenumberingWorker`**.
    @MainActor
    static func renumberDivesNewerThanDeleted(
        deletedStartTime: Date,
        deletedId: UUID,
        modelContext: ModelContext
    ) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let older = all.filter { chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let newer = all.filter { !chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let base = older.compactMap(\.diveNumber).max() ?? 0
        let newerSorted = newer.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var changed = false
        var next = base + 1
        for a in newerSorted {
            if a.diveNumberExplicitlyNone || a.diveNumber != next {
                a.diveNumberExplicitlyNone = false
                a.diveNumber = next
                changed = true
            }
            next += 1
        }
        if changed {
            try modelContext.save()
        }
    }

    /// Fills **`diveNumber`** for any persisted row still **`nil`** (e.g. store created before this feature).
    @MainActor
    static func backfillMissingDiveNumbers(modelContext: ModelContext) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        guard !all.isEmpty else { return }
        let map = sequentialIndicesById(for: all)
        var changed = false
        for a in all where a.diveNumber == nil && !a.diveNumberExplicitlyNone {
            a.diveNumber = map[a.id]
            changed = true
        }
        if changed {
            try modelContext.save()
        }
    }
}
