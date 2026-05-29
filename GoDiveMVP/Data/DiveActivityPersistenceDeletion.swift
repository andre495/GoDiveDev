import Foundation
import SwiftData

/// Deletes one **`DiveActivity`** and related rows on any **`ModelContext`** (background **`@ModelActor`** or UI).
enum DiveActivityPersistenceDeletion {

    struct Result: Sendable {
        let linkedSiteID: UUID?
    }

    /// Returns **`nil`** when no dive row matches **`diveID`**.
    @discardableResult
    nonisolated static func deleteDiveAndRelatedRecords(
        diveID: UUID,
        modelContext: ModelContext,
        runMarineLifeCleanup: Bool = true
    ) throws -> Result? {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1
        guard let activity = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let linkedSiteID = activity.diveSiteID
        let ownerProfileID = activity.ownerProfileID
        let mediaPhotoIDs = try modelContext.fetch(
            FetchDescriptor<DiveMediaPhoto>(
                predicate: #Predicate { $0.diveActivityID == diveID }
            )
        ).map(\.id)

        if runMarineLifeCleanup {
            try DiveActivityDeletionMarineLifeCleanup.removeDiveReferences(
                diveID: diveID,
                mediaPhotoIDs: mediaPhotoIDs,
                diveSiteID: linkedSiteID,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext,
                saveChanges: false
            )
        }

        DiveActivityRelationshipDetachment.detachNonCascadeRelationships(from: activity)
        try batchDeleteEquipmentRecords(diveID: diveID, modelContext: modelContext)

        modelContext.delete(activity)
        try modelContext.save()

        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(
            siteID: linkedSiteID,
            modelContext: modelContext
        )
        return Result(linkedSiteID: linkedSiteID)
    }

    /// Equipment rows only — cascade children must not be batch-deleted (Core Data inverse constraint).
    nonisolated static func batchDeleteEquipmentRecords(diveID: UUID, modelContext: ModelContext) throws {
        try modelContext.delete(
            model: DiveEquipmentEntry.self,
            where: #Predicate<DiveEquipmentEntry> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveActivityEquipmentList.self,
            where: #Predicate<DiveActivityEquipmentList> { $0.diveActivityID == diveID }
        )
    }
}
