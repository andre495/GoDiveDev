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

    func renumberDivesNewerThanDeleted(deletedStartTime: Date, deletedId: UUID) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let older = all.filter {
            DiveActivityDiveNumbering.chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId)
        }
        let newer = all.filter {
            DiveActivityDiveNumbering.chronologicallyAfterDeletedSlot(
                $0,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        }
        guard !newer.isEmpty else { return }

        let base = DiveActivityDiveNumbering.maxNumberedDiveNumber(among: older)
        let newerSorted = newer.sorted(by: DiveActivityDiveNumbering.isChronologicallyOrdered)
        if DiveActivityDiveNumbering.applyPartialRenumberTail(newerSorted: newerSorted, base: base) {
            try modelContext.save()
        }
    }
}
