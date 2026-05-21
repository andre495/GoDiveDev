import Foundation
import SwiftData

/// Deletes a dive and related rows off the main actor.
///
/// Equipment rows use **`delete(model:where:)`** batch delete. The **`DiveActivity`** itself is loaded once and
/// **`modelContext.delete`** — store-level batch delete of dives fails when a **`diveSite`** link exists (Core Data
/// mandatory nullify inverse). Profile points and buddies cascade from the parent delete.
@ModelActor
actor DiveBackgroundDeletionWorker {

    /// Deletes the dive with **`id`**. Returns whether post-delete renumber can be skipped.
    func deleteDive(
        id: UUID,
        deletedStartTime: Date,
        deletedId: UUID,
        shouldCheckRenumber: Bool
    ) throws -> Bool {
        let skipRenumber: Bool
        if shouldCheckRenumber {
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

        try deleteDiveAndRelatedRecords(diveID: id)
        try DiveSiteCatalogMaintenance.deleteSitesWithNoLinkedDives(modelContext: modelContext)
        return skipRenumber
    }

    private func deleteDiveAndRelatedRecords(diveID: UUID) throws {
        let diveID = diveID

        try modelContext.delete(
            model: DiveEquipmentEntry.self,
            where: #Predicate<DiveEquipmentEntry> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveActivityEquipmentList.self,
            where: #Predicate<DiveActivityEquipmentList> { $0.diveActivityID == diveID }
        )

        try DiveActivityMediaStorage.deleteMediaFiles(forDiveID: diveID, modelContext: modelContext)

        try deleteDiveViaParentCascade(diveID: diveID)
    }

    private func deleteDiveViaParentCascade(diveID: UUID) throws {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1

        guard let activity = try modelContext.fetch(descriptor).first else { return }

        activity.diveSite = nil
        activity.diveSiteID = nil
        modelContext.delete(activity)
        try modelContext.save()
    }
}
