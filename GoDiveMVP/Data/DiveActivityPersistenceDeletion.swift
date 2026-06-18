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

        DiveActivityRelationshipDetachment.detachNonCascadeRelationships(
            from: activity,
            modelContext: modelContext
        )

        modelContext.delete(activity)
        do {
            try modelContext.save()
        } catch {
            DiveActivityDeletionDebug.failure(diveID: diveID, error: error, contextLabel: "background-save")
            DiveActivityDeletionDebug.snapshot(diveID: diveID, contextLabel: "background-save", modelContext: modelContext)
            throw error
        }

        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(
            siteID: linkedSiteID,
            modelContext: modelContext
        )
        return Result(linkedSiteID: linkedSiteID)
    }
}
