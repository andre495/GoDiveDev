import Foundation
import SwiftData

/// Removes a deleted snorkel from **`MarineLifeUserRecord`** denormalized arrays.
enum SnorkelActivityDeletionMarineLifeCleanup {

    nonisolated static func removeSnorkelReferences(
        snorkelID: UUID,
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

        let mediaLinks = Set(
            mediaPhotoIDs.map(DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for:))
        )
        let ownerStillHasActivityAtSite: Bool
        if let diveSiteID {
            ownerStillHasActivityAtSite = try ownerHasLinkedActivity(
                atSiteID: diveSiteID,
                ownerProfileID: ownerProfileID,
                excludingSnorkelID: snorkelID,
                modelContext: modelContext
            )
        } else {
            ownerStillHasActivityAtSite = false
        }

        var changed = false
        for record in records {
            if record.activitiesSightedOn.contains(snorkelID) {
                var activities = record.activitiesSightedOn
                activities.removeAll { $0 == snorkelID }
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
               !ownerStillHasActivityAtSite {
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

    private nonisolated static func ownerHasLinkedActivity(
        atSiteID siteID: UUID,
        ownerProfileID: UUID,
        excludingSnorkelID: UUID,
        modelContext: ModelContext
    ) throws -> Bool {
        var diveDescriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { dive in
                dive.ownerProfileID == ownerProfileID && dive.diveSiteID == siteID
            }
        )
        diveDescriptor.fetchLimit = 1
        if try !modelContext.fetch(diveDescriptor).isEmpty {
            return true
        }

        var snorkelDescriptor = FetchDescriptor<SnorkelActivity>(
            predicate: #Predicate<SnorkelActivity> { snorkel in
                snorkel.ownerProfileID == ownerProfileID && snorkel.diveSiteID == siteID
            }
        )
        snorkelDescriptor.fetchLimit = 2
        let snorkels = try modelContext.fetch(snorkelDescriptor)
        return snorkels.contains { $0.id != excludingSnorkelID }
    }
}
