import Foundation
import SwiftData

/// Deletes a dive and related rows off the main actor.
///
/// Equipment rows use **`delete(model:where:)`** batch delete. Profile points, buddies, and media cascade when the
/// parent **`DiveActivity`** is deleted — store-level batch delete of those children fails (Core Data mandatory
/// nullify inverse on **`DiveProfilePoint.dive`**).
@ModelActor
actor DiveBackgroundDeletionWorker {

    /// Deletes the dive with **`id`**. Returns whether post-delete renumber can be skipped ( **`true`** when automatic renumber is off).
    func deleteDive(
        id: UUID,
        deletedStartTime: Date,
        deletedId: UUID,
        shouldCheckRenumber: Bool
    ) throws -> Bool {
        let linkedSiteID = try linkedSiteID(forDiveID: id)
        try deleteDiveAndRelatedRecords(diveID: id)
        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(siteID: linkedSiteID, modelContext: modelContext)
        return !shouldCheckRenumber
    }

    private func linkedSiteID(forDiveID diveID: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.diveSiteID
    }

    private func deleteDiveAndRelatedRecords(diveID: UUID) throws {
        try DiveActivityMediaStorage.deleteMediaFiles(forDiveID: diveID, modelContext: modelContext)

        try modelContext.delete(
            model: DiveEquipmentEntry.self,
            where: #Predicate<DiveEquipmentEntry> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveActivityEquipmentList.self,
            where: #Predicate<DiveActivityEquipmentList> { $0.diveActivityID == diveID }
        )

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
