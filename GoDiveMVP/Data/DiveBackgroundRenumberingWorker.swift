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

    func renumberDivesNewerThanDeleted(deletedStartTime: Date, deletedId: UUID) throws {
        let all = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        let older = all.filter {
            DiveActivityDiveNumbering.chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId)
        }
        let newer = all.filter {
            !DiveActivityDiveNumbering.chronologicallyBefore($0, deletedStartTime: deletedStartTime, deletedId: deletedId)
        }
        let base = older.filter { !$0.diveNumberExplicitlyNone }.compactMap(\.diveNumber).max() ?? 0
        let newerSorted = newer.sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var changed = false
        var next = base + 1
        for a in newerSorted where !a.diveNumberExplicitlyNone {
            if a.diveNumber != next {
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
