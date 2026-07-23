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

        for species in marineLife {
            _ = try tagSpecies(
                species,
                on: media,
                dive: dive,
                captureContext: captureContext,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
    }

    /// Persists multiple dive-level species tags (no media) with a single save at the end.
    static func tagPendingSpeciesOnDive(
        _ marineLife: [MarineLife],
        dive: DiveActivity,
        owner: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard !marineLife.isEmpty else { return }

        for species in marineLife {
            _ = try tagSpeciesOnDive(
                species,
                dive: dive,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
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

        for species in marineLife {
            _ = try tagSpecies(
                species,
                on: media,
                snorkel: snorkel,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
        DiveActivityMediaStorage.postMediaDidChange()
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
