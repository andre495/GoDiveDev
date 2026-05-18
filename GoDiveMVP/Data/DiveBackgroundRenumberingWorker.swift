import Foundation
import SwiftData

/// Off–main-actor SwiftData renumbering (**`@ModelActor`**) for post-delete persist without blocking Logbook.
@ModelActor
actor DiveBackgroundRenumberingWorker {

    func renumberAllChronologically() throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        guard !all.isEmpty else { return }
        let map = DiveActivityDiveNumbering.sequentialIndicesById(for: all)
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

    func renumberDivesNewerThanDeleted(deletedStartTime: Date, deletedId: UUID) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let older = all.filter {
            DiveActivityDiveNumbering.chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId)
        }
        let newer = all.filter {
            !DiveActivityDiveNumbering.chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId)
        }
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
}
