import Foundation
import SwiftData

/// Deletes one **`SnorkelActivity`** and related rows on any **`ModelContext`** (background **`@ModelActor`** or UI).
enum SnorkelActivityPersistenceDeletion {

    struct Result: Sendable {
        let linkedSiteID: UUID?
    }

    /// Returns **`nil`** when no snorkel row matches **`snorkelID`**.
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

        try deleteRelatedRecords(snorkelID: snorkelID, modelContext: modelContext)

        modelContext.delete(activity)
        do {
            try modelContext.save()
        } catch {
            SnorkelActivityDeletionDebug.failure(
                snorkelID: snorkelID,
                error: error,
                contextLabel: "background-save"
            )
            SnorkelActivityDeletionDebug.snapshot(
                snorkelID: snorkelID,
                contextLabel: "background-save",
                modelContext: modelContext
            )
            throw error
        }

        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(
            siteID: linkedSiteID,
            modelContext: modelContext
        )
        return Result(linkedSiteID: linkedSiteID)
    }

    /// Denormalized-ID batch deletes for children that may outlive cascade (orphans, join rows).
    private nonisolated static func deleteRelatedRecords(
        snorkelID: UUID,
        modelContext: ModelContext
    ) throws {
        try modelContext.delete(
            model: DiveMediaBuddyTag.self,
            where: #Predicate { $0.snorkelActivityID == snorkelID }
        )
        try modelContext.delete(
            model: SightingInstance.self,
            where: #Predicate { $0.snorkelActivityID == snorkelID }
        )
        try modelContext.delete(
            model: SnorkelBuddyTag.self,
            where: #Predicate { $0.snorkelActivityID == snorkelID }
        )
        try modelContext.delete(
            model: SnorkelMediaPhoto.self,
            where: #Predicate { $0.snorkelActivityID == snorkelID }
        )
    }
}
