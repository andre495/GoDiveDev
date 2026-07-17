import Foundation
import SwiftData

/// Removes a deleted dive from **`MarineLifeUserRecord`** denormalized arrays (activities, tagged media, sites).
enum DiveActivityDeletionMarineLifeCleanup {

    /// Media link token stored on **`MarineLifeUserRecord.userTaggedMedia`** when tagging from dive media.
    nonisolated static func userTaggedMediaLink(for mediaPhotoID: UUID) -> String {
        "media:\(mediaPhotoID.uuidString)"
    }

    /// Strips **`diveID`** (and related media / site references) from the owner's marine-life overlay rows.
    nonisolated static func removeDiveReferences(
        diveID: UUID,
        mediaPhotoIDs: [UUID],
        diveSiteID: UUID?,
        ownerProfileID: UUID?,
        modelContext: ModelContext,
        saveChanges: Bool = true
    ) throws {
        guard let ownerProfileID else { return }

        let records = try MarineLifeUserRecordOwnership.userRecords(
            forOwnerProfileID: ownerProfileID,
            modelContext: modelContext
        )
        guard !records.isEmpty else { return }

        let mediaLinks = Set(mediaPhotoIDs.map(userTaggedMediaLink(for:)))
        let ownerStillHasDiveAtSite: Bool
        if let diveSiteID {
            ownerStillHasDiveAtSite = try ownerHasDive(
                atSiteID: diveSiteID,
                ownerProfileID: ownerProfileID,
                excludingDiveID: diveID,
                modelContext: modelContext
            )
        } else {
            ownerStillHasDiveAtSite = false
        }

        var changed = false
        for record in records {
            if record.activitiesSightedOn.contains(diveID) {
                var activities = record.activitiesSightedOn
                activities.removeAll { $0 == diveID }
                record.activitiesSightedOn = activities
                changed = true
            }

            let mediaBefore = record.userTaggedMedia.count
            var mediaLinksOnRecord = record.userTaggedMedia
            mediaLinksOnRecord.removeAll { mediaLinks.contains($0) }
            if mediaLinksOnRecord.count != mediaBefore {
                record.userTaggedMedia = mediaLinksOnRecord
                changed = true
            }

            if let diveSiteID,
               record.sitesSightedOn.contains(diveSiteID),
               !ownerStillHasDiveAtSite {
                var sites = record.sitesSightedOn
                sites.removeAll { $0 == diveSiteID }
                record.sitesSightedOn = sites
                changed = true
            }
        }

        if changed, saveChanges {
            try modelContext.save()
        }
    }

    private nonisolated static func ownerHasDive(
        atSiteID siteID: UUID,
        ownerProfileID: UUID,
        excludingDiveID: UUID,
        modelContext: ModelContext
    ) throws -> Bool {
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { dive in
                dive.ownerProfileID == ownerProfileID && dive.diveSiteID == siteID
            }
        )
        descriptor.fetchLimit = 2
        let matches = try modelContext.fetch(descriptor)
        return matches.contains { $0.id != excludingDiveID }
    }
}
