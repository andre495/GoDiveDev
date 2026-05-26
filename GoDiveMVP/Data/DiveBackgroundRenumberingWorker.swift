import Foundation
import SwiftData

/// Off–main-actor SwiftData renumbering (**`@ModelActor`**) for post-delete persist without blocking Logbook.
@ModelActor
actor DiveBackgroundRenumberingWorker {

    func renumberAllChronologically() throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        guard !all.isEmpty else { return }
        let map = DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: all)
        var changed = false
        for activity in all where !activity.diveNumberExplicitlyNone {
            guard let next = map[activity.id] else { continue }
            if activity.diveNumber != next {
                activity.diveNumber = next
                changed = true
            }
        }
        if changed {
            try modelContext.save()
        }
    }

    /// Tail renumber with predicate-scoped fetches (tie-break on **`id`** applied in memory).
    func renumberDivesNewerThanDeleted(deletedStartTime: Date, deletedId: UUID) throws {
        let newerCandidates = try modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { dive in
                    dive.startTime > deletedStartTime
                        || dive.startTime == deletedStartTime
                }
            )
        )
        let newer = newerCandidates.filter {
            DiveActivityDiveNumbering.chronologicallyAfterDeletedSlot(
                $0,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        }
        guard !newer.isEmpty else { return }

        let olderCandidates = try modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { dive in
                    dive.startTime < deletedStartTime
                        || dive.startTime == deletedStartTime
                }
            )
        )
        let older = olderCandidates.filter {
            DiveActivityDiveNumbering.chronologicallyBefore(
                $0,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        }
        let base = DiveActivityDiveNumbering.maxNumberedDiveNumber(among: older)
        let newerSorted = newer.sorted(by: DiveActivityDiveNumbering.isChronologicallyOrdered)
        if DiveActivityDiveNumbering.applyPartialRenumberTail(newerSorted: newerSorted, base: base) {
            try modelContext.save()
        }
    }
}
