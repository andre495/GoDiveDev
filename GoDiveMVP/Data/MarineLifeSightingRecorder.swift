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
            marineLife: marineLife,
            dive: dive,
            diveSite: dive.diveSite,
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

    private static func syncUserRecord(
        marineLife: MarineLife,
        dive: DiveActivity,
        media: DiveMediaPhoto,
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
            record.activitiesSightedOn.append(dive.id)
        }
        if let siteID = dive.diveSiteID, !record.sitesSightedOn.contains(siteID) {
            record.sitesSightedOn.append(siteID)
        }

        let mediaLink = userTaggedMediaLink(for: media)
        if !record.userTaggedMedia.contains(mediaLink) {
            record.userTaggedMedia.append(mediaLink)
        }

        if persistImmediately {
            try modelContext.save()
        }
    }

    private static func userTaggedMediaLink(for media: DiveMediaPhoto) -> String {
        "media:\(media.id.uuidString)"
    }
}
