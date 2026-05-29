import Foundation
import SwiftData

/// Deletes one **`DiveActivity`** and its related rows on a background **`ModelContext`** (**`@ModelActor`**).
///
/// Uses **`delete(model:where:)`** for equipment and child rows (SQL deletes, no in-memory cascade walk), then
/// batch-deletes the dive. Profile points with large FIT imports are the main cost if the parent row is deleted via
/// **`modelContext.delete(activity)`** alone.
@ModelActor
actor DiveBackgroundDeletionWorker {

    enum DeletionError: Error, Equatable {
        case diveNotFound(UUID)
    }

    /// Removes the dive and related data. Throws **`DeletionError.diveNotFound`** when no row matches **`id`**.
    func deleteDive(id: UUID) throws {
        let linkedSiteID = try linkedSiteID(forDiveID: id)
        guard try deleteDiveAndRelatedRecords(diveID: id) else {
            throw DeletionError.diveNotFound(id)
        }
        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(siteID: linkedSiteID, modelContext: modelContext)
    }

    private func linkedSiteID(forDiveID diveID: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.diveSiteID
    }

    @discardableResult
    private func deleteDiveAndRelatedRecords(diveID: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1
        guard let activity = try modelContext.fetch(descriptor).first else {
            return false
        }

        syncDenormalizedChildIDs(on: activity)

        // Media rows are Photos-library references (no app-side files to remove); just drop the DB rows.
        detachRelatedRecords(from: activity)
        try modelContext.save()

        try batchDeleteRelatedRecords(diveID: diveID)

        try modelContext.delete(
            model: DiveActivity.self,
            where: #Predicate<DiveActivity> { $0.id == diveID }
        )
        try modelContext.save()

        return true
    }

    /// Ensures batch **`delete(model:where:)`** predicates match rows linked only via inverse relationships.
    private func syncDenormalizedChildIDs(on activity: DiveActivity) {
        let diveID = activity.id
        for buddy in activity.buddies where buddy.diveActivityID != diveID {
            buddy.diveActivityID = diveID
        }
        for point in activity.profilePoints where point.diveActivityID != diveID {
            point.diveActivityID = diveID
        }
        for photo in activity.mediaPhotos where photo.diveActivityID != diveID {
            photo.diveActivityID = diveID
        }
    }

    /// Breaks SwiftData relationship inverses so **`delete(model:where:)`** can run (batch delete fails on linked rows).
    private func detachRelatedRecords(from activity: DiveActivity) {
        for buddy in activity.buddies {
            buddy.dive = nil
        }
        activity.buddies.removeAll()

        let linkedTags = activity.activityTags
        for tag in linkedTags {
            tag.dives.removeAll { $0.id == activity.id }
        }

        for point in activity.profilePoints {
            point.dive = nil
        }
        activity.profilePoints.removeAll()

        for photo in activity.mediaPhotos {
            photo.dive = nil
        }
        activity.mediaPhotos.removeAll()

        if let equipmentList = activity.equipmentList {
            for entry in equipmentList.entries {
                entry.equipmentList = nil
            }
            equipmentList.entries.removeAll()
            equipmentList.dive = nil
        }
        activity.equipmentList = nil

        activity.diveSite = nil
        activity.diveSiteID = nil
    }

    private func batchDeleteRelatedRecords(diveID: UUID) throws {
        try modelContext.delete(
            model: DiveEquipmentEntry.self,
            where: #Predicate<DiveEquipmentEntry> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveActivityEquipmentList.self,
            where: #Predicate<DiveActivityEquipmentList> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveProfilePoint.self,
            where: #Predicate<DiveProfilePoint> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveBuddyTag.self,
            where: #Predicate<DiveBuddyTag> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: SightingInstance.self,
            where: #Predicate<SightingInstance> { $0.diveActivityID == diveID }
        )
        try modelContext.delete(
            model: DiveMediaPhoto.self,
            where: #Predicate<DiveMediaPhoto> { $0.diveActivityID == diveID }
        )
    }
}
