import Foundation
import SwiftData

/// Creates **`SightingInstance`** rows from dive media tagging and updates **`MarineLifeUserRecord`**.
enum MarineLifeSightingRecorder {

    static func sightings(
        forDiveSiteID diveSiteID: UUID,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { $0.diveSiteID == diveSiteID },
            sortBy: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    static func sightings(
        forMediaPhotoID mediaPhotoID: UUID,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { $0.mediaPhotoID == mediaPhotoID },
            sortBy: [SortDescriptor(\.sightingDateTime)]
        )
        return try modelContext.fetch(descriptor)
    }

    static func sightings(
        forDiveActivityID diveActivityID: UUID,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { $0.diveActivityID == diveActivityID },
            sortBy: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches sightings for the given dives — avoids loading the full sighting table on trip detail.
    static func sightings(
        forDiveActivityIDs diveActivityIDs: Set<UUID>,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        guard !diveActivityIDs.isEmpty else { return [] }
        var merged: [SightingInstance] = []
        var seen = Set<String>()
        for diveID in diveActivityIDs {
            let rows = try sightings(forDiveActivityID: diveID, modelContext: modelContext)
            for row in rows where seen.insert(row.sightingUUID).inserted {
                merged.append(row)
            }
        }
        return merged
    }

    /// Fetches sightings for buddy-tagged media — avoids loading the full sighting table on buddy detail.
    static func sightings(
        forMediaPhotoIDs mediaPhotoIDs: Set<UUID>,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        guard !mediaPhotoIDs.isEmpty else { return [] }
        var merged: [SightingInstance] = []
        var seen = Set<String>()
        for mediaID in mediaPhotoIDs {
            let rows = try sightings(forMediaPhotoID: mediaID, modelContext: modelContext)
            for row in rows where seen.insert(row.sightingUUID).inserted {
                merged.append(row)
            }
        }
        return merged
    }

    static func existingSighting(
        marineLifeUUID: String,
        mediaPhotoID: UUID,
        modelContext: ModelContext
    ) throws -> SightingInstance? {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> {
                $0.marineLifeUUID == marineLifeUUID && $0.mediaPhotoID == mediaPhotoID
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Any sighting of this species on the dive (media-linked or dive-level).
    static func existingSightingOnDive(
        marineLifeUUID: String,
        diveActivityID: UUID,
        modelContext: ModelContext
    ) throws -> SightingInstance? {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> {
                $0.marineLifeUUID == marineLifeUUID && $0.diveActivityID == diveActivityID
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    static func tagSpecies(
        _ marineLife: MarineLife,
        on media: DiveMediaPhoto,
        dive: DiveActivity,
        captureContext: DiveMediaCaptureContext?,
        owner: UserProfile,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> SightingInstance {
        if let existing = try existingSighting(
            marineLifeUUID: marineLife.uuid,
            mediaPhotoID: media.id,
            modelContext: modelContext
        ) {
            try syncUserRecord(
                marineLife: marineLife,
                dive: dive,
                media: media,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: persistImmediately
            )
            if persistImmediately {
                DiveActivityMediaStorage.postMediaDidChange()
            }
            return existing
        }

        let draft = SightingInstanceCreation.makeDraft(
            marineLifeUUID: marineLife.uuid,
            dive: dive,
            mediaPhoto: media,
            sightingDepthMeters: captureContext?.depthMeters
        )
        let sighting = try SightingInstanceCreation.insert(
            draft: draft,
            dive: dive,
            mediaPhoto: media,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        try syncUserRecord(
            marineLife: marineLife,
            dive: dive,
            media: media,
            owner: owner,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        if persistImmediately {
            DiveActivityMediaStorage.postMediaDidChange()
        }
        return sighting
    }

    /// Tags a species on the dive without linking media. No-ops when the species is already
    /// sighted on this dive (including via a media tag).
    @discardableResult
    static func tagSpeciesOnDive(
        _ marineLife: MarineLife,
        dive: DiveActivity,
        owner: UserProfile,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> SightingInstance {
        if let existing = try existingSightingOnDive(
            marineLifeUUID: marineLife.uuid,
            diveActivityID: dive.id,
            modelContext: modelContext
        ) {
            try syncUserRecord(
                marineLife: marineLife,
                dive: dive,
                media: nil,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: persistImmediately
            )
            return existing
        }

        let draft = SightingInstanceCreation.makeDraft(
            marineLifeUUID: marineLife.uuid,
            dive: dive,
            mediaPhoto: nil
        )
        let sighting = try SightingInstanceCreation.insert(
            draft: draft,
            dive: dive,
            mediaPhoto: nil,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        try syncUserRecord(
            marineLife: marineLife,
            dive: dive,
            media: nil,
            owner: owner,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        return sighting
    }

    /// Persists multiple pending media tags with a single save at the end.
    static func tagPendingSpecies(
        _ marineLife: [MarineLife],
        on media: DiveMediaPhoto,
        dive: DiveActivity,
        captureContext: DiveMediaCaptureContext?,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard !marineLife.isEmpty else { return }

        var created: [SightingInstance] = []
        for species in marineLife {
            let sighting = try tagSpecies(
                species,
                on: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
            created.append(sighting)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
        scheduleCommunityContributionUpserts(created, modelContext: modelContext)
    }

    /// Persists multiple dive-level species tags (no media) with a single save at the end.
    static func tagPendingSpeciesOnDive(
        _ marineLife: [MarineLife],
        dive: DiveActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard !marineLife.isEmpty else { return }

        var created: [SightingInstance] = []
        for species in marineLife {
            let sighting = try tagSpeciesOnDive(
                species,
                dive: dive,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
            created.append(sighting)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        scheduleCommunityContributionUpserts(created, modelContext: modelContext)
    }

    /// Removes media-linked sightings for the species on this photo and updates overlays.
    static func untagSpecies(
        marineLifeUUID: String,
        on media: DiveMediaPhoto,
        dive: DiveActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        let rows = try sightings(forMediaPhotoID: media.id, modelContext: modelContext)
            .filter { $0.marineLifeUUID == marineLifeUUID }
        let deletedUUIDs = rows.map(\.sightingUUID)
        for row in rows {
            modelContext.delete(row)
        }
        try clearUserRecordLinksAfterUntag(
            marineLifeUUID: marineLifeUUID,
            activityID: dive.id,
            diveSiteID: dive.diveSiteID,
            mediaLink: userTaggedMediaLink(for: media),
            owner: owner,
            modelContext: modelContext,
            remainingOnActivity: {
                try existingSightingOnDive(
                    marineLifeUUID: marineLifeUUID,
                    diveActivityID: dive.id,
                    modelContext: modelContext
                ) != nil
            }
        )
        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
        scheduleCommunityContributionDeletes(deletedUUIDs)
    }

    /// Removes dive-level (and media-linked) sightings of the species on this dive.
    static func untagSpeciesOnDive(
        marineLifeUUID: String,
        dive: DiveActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        let rows = try sightings(forDiveActivityID: dive.id, modelContext: modelContext)
            .filter { $0.marineLifeUUID == marineLifeUUID }
        let deletedUUIDs = rows.map(\.sightingUUID)
        for row in rows {
            modelContext.delete(row)
        }
        try clearUserRecordLinksAfterUntag(
            marineLifeUUID: marineLifeUUID,
            activityID: dive.id,
            diveSiteID: dive.diveSiteID,
            mediaLink: nil,
            owner: owner,
            modelContext: modelContext,
            remainingOnActivity: { false }
        )
        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
        scheduleCommunityContributionDeletes(deletedUUIDs)
    }

    // MARK: - Snorkel

    static func sightings(
        forSnorkelActivityID snorkelActivityID: UUID,
        modelContext: ModelContext
    ) throws -> [SightingInstance] {
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { $0.snorkelActivityID == snorkelActivityID },
            sortBy: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    static func tagSpecies(
        _ marineLife: MarineLife,
        on media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        owner: UserProfile,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> SightingInstance {
        if let existing = try existingSighting(
            marineLifeUUID: marineLife.uuid,
            mediaPhotoID: media.id,
            modelContext: modelContext
        ) {
            try syncUserRecordSnorkel(
                marineLife: marineLife,
                snorkel: snorkel,
                media: media,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: persistImmediately
            )
            if persistImmediately {
                DiveActivityMediaStorage.postMediaDidChange()
            }
            return existing
        }

        let draft = SnorkelSightingInstanceCreation.makeDraft(
            marineLifeUUID: marineLife.uuid,
            snorkel: snorkel,
            mediaPhoto: media
        )
        let sighting = try SnorkelSightingInstanceCreation.insert(
            draft: draft,
            snorkel: snorkel,
            mediaPhoto: media,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        try syncUserRecordSnorkel(
            marineLife: marineLife,
            snorkel: snorkel,
            media: media,
            owner: owner,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        )
        if persistImmediately {
            DiveActivityMediaStorage.postMediaDidChange()
        }
        return sighting
    }

    static func tagPendingSpecies(
        _ marineLife: [MarineLife],
        on media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard !marineLife.isEmpty else { return }

        var created: [SightingInstance] = []
        for species in marineLife {
            let sighting = try tagSpecies(
                species,
                on: media,
                snorkel: snorkel,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
            created.append(sighting)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
        scheduleCommunityContributionUpserts(created, modelContext: modelContext)
    }

    static func untagSpecies(
        marineLifeUUID: String,
        on media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        let rows = try sightings(forSnorkelActivityID: snorkel.id, modelContext: modelContext)
            .filter {
                $0.marineLifeUUID == marineLifeUUID && $0.snorkelMediaPhotoID == media.id
            }
        let deletedUUIDs = rows.map(\.sightingUUID)
        for row in rows {
            modelContext.delete(row)
        }
        try clearUserRecordLinksAfterUntag(
            marineLifeUUID: marineLifeUUID,
            activityID: snorkel.id,
            diveSiteID: snorkel.diveSiteID,
            mediaLink: "media:\(media.id.uuidString)",
            owner: owner,
            modelContext: modelContext,
            remainingOnActivity: {
                let remaining = try sightings(
                    forSnorkelActivityID: snorkel.id,
                    modelContext: modelContext
                )
                return remaining.contains { $0.marineLifeUUID == marineLifeUUID }
            }
        )
        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
        scheduleCommunityContributionDeletes(deletedUUIDs)
    }

    private static func clearUserRecordLinksAfterUntag(
        marineLifeUUID: String,
        activityID: UUID,
        diveSiteID: UUID?,
        mediaLink: String?,
        owner: UserProfile,
        modelContext: ModelContext,
        remainingOnActivity: () throws -> Bool
    ) throws {
        let records = try MarineLifeUserRecordOwnership.userRecords(
            forOwnerProfileID: owner.id,
            modelContext: modelContext
        )
        guard let record = MarineLifeUserRecordOwnership.userRecord(
            marineLifeUUID: marineLifeUUID,
            ownerProfileID: owner.id,
            in: records
        ) else { return }

        if let mediaLink {
            record.userTaggedMedia = record.userTaggedMedia.filter { $0 != mediaLink }
        }
        if try !remainingOnActivity() {
            record.activitiesSightedOn = record.activitiesSightedOn.filter { $0 != activityID }
        }
        if record.activitiesSightedOn.isEmpty {
            record.isSighted = false
            if let diveSiteID {
                record.sitesSightedOn = record.sitesSightedOn.filter { $0 != diveSiteID }
            }
        }
    }

    private static func scheduleCommunityContributionUpserts(
        _ sightings: [SightingInstance],
        modelContext: ModelContext
    ) {
        let uuids = sightings.map(\.sightingUUID)
        guard !uuids.isEmpty else { return }
        let container = modelContext.container
        Task { @MainActor in
            let context = ModelContext(container)
            var resolved: [SightingInstance] = []
            for uuid in uuids {
                var descriptor = FetchDescriptor<SightingInstance>(
                    predicate: #Predicate<SightingInstance> { $0.sightingUUID == uuid }
                )
                descriptor.fetchLimit = 1
                if let sighting = try? context.fetch(descriptor).first {
                    resolved.append(sighting)
                }
            }
            await OntologySightingContributionSync.syncAfterTags(
                sightings: resolved,
                modelContext: context
            )
        }
    }

    private static func scheduleCommunityContributionDeletes(_ sightingUUIDs: [String]) {
        guard !sightingUUIDs.isEmpty else { return }
        Task { @MainActor in
            await OntologySightingContributionSync.markDeleted(sightingUUIDs: sightingUUIDs)
        }
    }

    private static func syncUserRecordSnorkel(
        marineLife: MarineLife,
        snorkel: SnorkelActivity,
        media: SnorkelMediaPhoto?,
        owner: UserProfile,
        modelContext: ModelContext,
        persistImmediately: Bool
    ) throws {
        let record = try MarineLifeUserRecordOwnership.getOrCreate(
            for: marineLife,
            owner: owner,
            modelContext: modelContext
        )
        record.isSighted = true

        if !record.activitiesSightedOn.contains(snorkel.id) {
            var activities = record.activitiesSightedOn
            activities.append(snorkel.id)
            record.activitiesSightedOn = activities
        }
        if let siteID = snorkel.diveSiteID, !record.sitesSightedOn.contains(siteID) {
            var sites = record.sitesSightedOn
            sites.append(siteID)
            record.sitesSightedOn = sites
        }

        if let media {
            let mediaLink = "media:\(media.id.uuidString)"
            if !record.userTaggedMedia.contains(mediaLink) {
                var mediaLinks = record.userTaggedMedia
                mediaLinks.append(mediaLink)
                record.userTaggedMedia = mediaLinks
            }
        }

        if persistImmediately {
            try modelContext.save()
        }
    }

    private static func syncUserRecord(
        marineLife: MarineLife,
        dive: DiveActivity,
        media: DiveMediaPhoto?,
        owner: UserProfile,
        modelContext: ModelContext,
        persistImmediately: Bool
    ) throws {
        let record = try MarineLifeUserRecordOwnership.getOrCreate(
            for: marineLife,
            owner: owner,
            modelContext: modelContext
        )
        record.isSighted = true

        if !record.activitiesSightedOn.contains(dive.id) {
            var activities = record.activitiesSightedOn
            activities.append(dive.id)
            record.activitiesSightedOn = activities
        }
        if let siteID = dive.diveSiteID, !record.sitesSightedOn.contains(siteID) {
            var sites = record.sitesSightedOn
            sites.append(siteID)
            record.sitesSightedOn = sites
        }

        if let media {
            let mediaLink = userTaggedMediaLink(for: media)
            if !record.userTaggedMedia.contains(mediaLink) {
                var mediaLinks = record.userTaggedMedia
                mediaLinks.append(mediaLink)
                record.userTaggedMedia = mediaLinks
            }
        }

        if persistImmediately {
            try modelContext.save()
        }
    }

    private static func userTaggedMediaLink(for media: DiveMediaPhoto) -> String {
        "media:\(media.id.uuidString)"
    }
}
