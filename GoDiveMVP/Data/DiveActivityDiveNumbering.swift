import Foundation
import SwiftData

/// Persists **`DiveActivity.diveNumber`** so Logbook and single-dive screens stay aligned.
///
/// **Rules**
/// - **`.fit` import:** **`assignNextDiveNumberChainedAfterNewest`** — next **#** is **(last numbered dive in **`startTime`** order) + 1**; dives with **`diveNumber == nil`** (unset or **`diveNumberExplicitlyNone`**) do not advance the chain. Garmin **`SessionMesg`** is not used.
/// - **After delete (when automatic renumber is on in Settings):** **`DiveBackgroundRenumberingWorker`** (**`@ModelActor`**) tail-renumbers off the main actor (predicate-scoped fetches). Logbook labels use chronological display when automatic renumber is on. **`renumberAllChronologically`** on the main context is for Settings / import. Dives with **`diveNumberExplicitlyNone`** (logbook **`-`**) are never renumbered and do not consume a **#** slot.
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

    /// Chronological **1…n** for dives that show a **#** in the logbook (skips **`diveNumberExplicitlyNone`** / **`-`**).
    nonisolated static func numberedDiveSequentialIndicesById(for activities: [DiveActivity]) -> [UUID: Int] {
        numberedDiveSequentialIndicesById(
            for: activities.map {
                NumberingRow(
                    id: $0.id,
                    startTime: $0.startTime,
                    diveNumberExplicitlyNone: $0.diveNumberExplicitlyNone
                )
            }
        )
    }

    struct NumberingRow: Sendable {
        let id: UUID
        let startTime: Date
        let diveNumberExplicitlyNone: Bool

        nonisolated init(id: UUID, startTime: Date, diveNumberExplicitlyNone: Bool) {
            self.id = id
            self.startTime = startTime
            self.diveNumberExplicitlyNone = diveNumberExplicitlyNone
        }
    }

    nonisolated static func numberedDiveSequentialIndicesById(for rows: [NumberingRow]) -> [UUID: Int] {
        numberedDiveSequentialIndicesById(rows: rows)
    }

    private nonisolated static func numberedDiveSequentialIndicesById(rows: [NumberingRow]) -> [UUID: Int] {
        guard !rows.isEmpty else { return [:] }
        let sorted = rows.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var map: [UUID: Int] = [:]
        var next = 1
        for row in sorted where !row.diveNumberExplicitlyNone {
            map[row.id] = next
            next += 1
        }
        return map
    }

    /// **`a`** is strictly after **`(deletedStartTime, deletedId)`** (excludes the deleted row when still present).
    nonisolated static func chronologicallyAfterDeletedSlot(
        _ a: DiveActivity,
        deletedStartTime: Date,
        deletedId: UUID
    ) -> Bool {
        !chronologicallyBefore(a, deletedStartTime: deletedStartTime, deletedId: deletedId)
            && a.id != deletedId
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

    /// Sort key for **`startTime`** then **`id`** (shared by renumber + partial tail passes).
    nonisolated static func isChronologicallyOrdered(_ lhs: DiveActivity, _ rhs: DiveActivity) -> Bool {
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated static func maxNumberedDiveNumber(among activities: [DiveActivity]) -> Int {
        activities.filter { !$0.diveNumberExplicitlyNone }.compactMap(\.diveNumber).max() ?? 0
    }

    /// Rewrites **`diveNumber`** on **`newerSorted`** to **`base + 1`**, **`base + 2`**, … Skips **`-`** dives. Returns whether any row changed.
    nonisolated static func applyPartialRenumberTail(newerSorted: [DiveActivity], base: Int) -> Bool {
        var changed = false
        var next = base + 1
        for activity in newerSorted where !activity.diveNumberExplicitlyNone {
            if activity.diveNumber != next {
                activity.diveNumber = next
                changed = true
            }
            next += 1
        }
        return changed
    }

    /// **`true`** when renumbering **only** dives after the deleted slot would not write any row.
    nonisolated static func partialRenumberAfterDeleteWouldBeNoop(
        remaining: [DiveActivity],
        deletedStartTime: Date,
        deletedId: UUID
    ) -> Bool {
        guard !remaining.isEmpty else { return true }
        let older = remaining.filter { chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let newer = remaining.filter { chronologicallyAfterDeletedSlot($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let base = maxNumberedDiveNumber(among: older)
        let newerSorted = newer.sorted(by: isChronologicallyOrdered)
        var next = base + 1
        for activity in newerSorted where !activity.diveNumberExplicitlyNone {
            if activity.diveNumber != next {
                return false
            }
            next += 1
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

    static func assignNextDiveNumberChainedAfterNewest(for activity: DiveActivity, modelContext: ModelContext) throws {
        var existing = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        assignNextChainedDiveNumber(to: activity, among: &existing)
    }

    /// In-memory chained **#** for batch import (avoids refetching the logbook each dive).
    nonisolated static func assignNextChainedDiveNumber(to activity: DiveActivity, among existingDives: inout [DiveActivity]) {
        activity.diveNumber = nextChainedDiveNumberForNewImport(existingDives: existingDives)
        activity.diveNumberExplicitlyNone = false
        existingDives.append(activity)
    }

    /// Rewrites **`diveNumber`** on numbered dives to **1…n** in **`startTime`** order (ties **`id`**); leaves **`-`** dives untouched.
    static func renumberAllChronologically(modelContext: ModelContext) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        guard !all.isEmpty else { return }
        let map = numberedDiveSequentialIndicesById(for: all)
        var changed = false
        for a in all where !a.diveNumberExplicitlyNone {
            guard let next = map[a.id] else { continue }
            if a.diveNumber != next {
                a.diveNumber = next
                changed = true
            }
        }
        if changed {
            try modelContext.save()
        }
    }

    static func applyAutomaticSequentialRenumberIfNeeded(modelContext: ModelContext) throws {
        guard AppUserSettings.automaticallyRenumberDives else { return }
        try renumberAllChronologically(modelContext: modelContext)
    }

    /// Renumbers only dives **strictly after** **`(deletedStartTime, deletedId)`** in chronological order: **`base + 1`**, **`base + 2`**, … where **`base`** = **`max(diveNumber)`** among older dives (or **0**). Older dives are untouched.
    static func renumberDivesNewerThanDeleted(
        deletedStartTime: Date,
        deletedId: UUID,
        modelContext: ModelContext
    ) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let older = all.filter { chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        let newer = all.filter { chronologicallyAfterDeletedSlot($0, deletedStartTime: deletedStartTime, deletedId: deletedId) }
        guard !newer.isEmpty else { return }
        let base = maxNumberedDiveNumber(among: older)
        let newerSorted = newer.sorted(by: isChronologicallyOrdered)
        if applyPartialRenumberTail(newerSorted: newerSorted, base: base) {
            try modelContext.save()
        }
    }

    /// Fills **`diveNumber`** for any persisted row still **`nil`** (e.g. store created before this feature).
    nonisolated static func backfillMissingDiveNumbers(modelContext: ModelContext) throws {
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
