import Foundation
import SwiftData

/// Deletes one **`SnorkelActivity`** and related rows on any **`ModelContext`**.
enum SnorkelActivityPersistenceDeletion {

    struct Result: Sendable {
        let linkedSiteID: UUID?
    }

    @discardableResult
    nonisolated static func deleteSnorkelAndRelatedRecords(
        snorkelID: UUID,
        modelContext: ModelContext,
        runMarineLifeCleanup: Bool = true
    ) throws -> Result? {
        var descriptor = FetchDescriptor<SnorkelActivity>(
            predicate: #Predicate { $0.id == snorkelID }
        )
        descriptor.fetchLimit = 1
        guard let activity = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let linkedSiteID = activity.diveSiteID
        let ownerProfileID = activity.ownerProfileID
        let mediaPhotoIDs = try modelContext.fetch(
            FetchDescriptor<SnorkelMediaPhoto>(
                predicate: #Predicate { $0.snorkelActivityID == snorkelID }
            )
        ).map(\.id)

        if runMarineLifeCleanup {
            try SnorkelActivityDeletionMarineLifeCleanup.removeSnorkelReferences(
                snorkelID: snorkelID,
                mediaPhotoIDs: mediaPhotoIDs,
                diveSiteID: linkedSiteID,
                ownerProfileID: ownerProfileID,
                modelContext: modelContext,
                saveChanges: false
            )
        }

        try SnorkelProfilePointStore.deletePoints(for: snorkelID, modelContext: modelContext)

        SnorkelActivityRelationshipDetachment.detachNonCascadeRelationships(
            from: activity,
            modelContext: modelContext
        )

        modelContext.delete(activity)
        try modelContext.save()

        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(
            siteID: linkedSiteID,
            modelContext: modelContext
        )
        return Result(linkedSiteID: linkedSiteID)
    }
}
