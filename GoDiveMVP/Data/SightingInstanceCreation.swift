import Foundation
import SwiftData

/// Inserts **`SightingInstance`** rows (tag-from-dive / tag-from-media UI will call this next).
enum SightingInstanceCreation {

    struct Draft: Sendable {
        var sightingUUID: String
        var marineLifeUUID: String
        var sightingDateTime: Date
        var diveActivityID: UUID
        var diveSiteID: UUID?
        var sightingDepthMeters: Double?
        var mediaPhotoID: UUID?
    }

    static func makeDraft(
        marineLifeUUID: String,
        dive: DiveActivity,
        mediaPhoto: DiveMediaPhoto? = nil,
        sightingDepthMeters: Double? = nil,
        sightingUUID: String = UUID().uuidString
    ) -> Draft {
        Draft(
            sightingUUID: sightingUUID,
            marineLifeUUID: marineLifeUUID,
            sightingDateTime: SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                diveStartTime: dive.startTime,
                mediaCapturedAt: mediaPhoto?.capturedAt
            ),
            diveActivityID: dive.id,
            diveSiteID: dive.diveSiteID,
            sightingDepthMeters: sightingDepthMeters,
            mediaPhotoID: mediaPhoto?.id
        )
    }

    @discardableResult
    static func insert(
        draft: Draft,
        marineLife: MarineLife,
        dive: DiveActivity,
        diveSite: DiveSite? = nil,
        mediaPhoto: DiveMediaPhoto? = nil,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) throws -> SightingInstance {
        let sighting = SightingInstance(
            sightingUUID: draft.sightingUUID,
            marineLifeUUID: draft.marineLifeUUID,
            sightingDateTime: draft.sightingDateTime,
            sightingDepthMeters: draft.sightingDepthMeters,
            mediaPhoto: mediaPhoto
        )
        SightingInstanceLinking.link(
            sighting,
            marineLife: marineLife,
            dive: dive,
            diveSite: diveSite,
            mediaPhoto: mediaPhoto
        )
        modelContext.insert(sighting)
        if persistImmediately {
            try modelContext.save()
        }
        return sighting
    }
}
