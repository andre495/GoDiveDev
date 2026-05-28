import Foundation
import SwiftData

/// Tagged dive media for **Field Guide** species detail and **Explore** dive-site detail.
enum FieldGuideTaggedMediaPresentation {

    struct GalleryPayload: Equatable, Sendable {
        let mediaItemIDs: [UUID]
        let timeZoneOffsetByMediaID: [UUID: Int?]
    }

    /// Token for `.task(id:)` when sightings or owner scope change.
    nonisolated static func galleryRefreshToken(
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>
    ) -> String {
        let firstSightingID = sightings.first?.sightingUUID ?? ""
        let lastMediaID = sightings.compactMap(\.mediaPhotoID).last?.uuidString ?? ""
        return "\(sightings.count)|\(firstSightingID)|\(lastMediaID)|\(ownerDiveActivityIDs.count)"
    }

    nonisolated static func galleryPayload(
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>,
        timeZoneOffsetByActivityID: [UUID: Int?]
    ) -> GalleryPayload {
        let photos = taggedMediaPhotos(
            sightings: sightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs
        )
        return GalleryPayload(
            mediaItemIDs: photos.map(\.id),
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID(
                sightings: sightings,
                ownerDiveActivityIDs: ownerDiveActivityIDs,
                timeZoneOffsetByActivityID: timeZoneOffsetByActivityID
            )
        )
    }

    /// Unique **`DiveMediaPhoto`** rows for the signed-in user's dives, gallery order (oldest capture first).
    nonisolated static func taggedMediaPhotos(
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>
    ) -> [DiveMediaPhoto] {
        guard !ownerDiveActivityIDs.isEmpty else { return [] }

        var seenPhotoIDs = Set<UUID>()
        var photos: [DiveMediaPhoto] = []

        for sighting in sightings {
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let photo = sighting.mediaPhoto,
                  seenPhotoIDs.insert(photo.id).inserted
            else { continue }
            photos.append(photo)
        }

        return photos.sorted(by: DiveActivityMediaPresentation.isOrderedBeforeInGallery)
    }

    /// Resolves photos by **`mediaPhotoID`** when the SwiftData relationship is not faulted in (detail pages).
    @MainActor
    static func resolvedTaggedMediaPhotos(
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [DiveMediaPhoto] {
        guard !ownerDiveActivityIDs.isEmpty else { return [] }

        let mediaByID = mediaPhotosByID(
            for: sightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )

        var seenPhotoIDs = Set<UUID>()
        var photos: [DiveMediaPhoto] = []

        for sighting in sightings {
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaID = sighting.mediaPhotoID,
                  let photo = mediaByID[mediaID],
                  seenPhotoIDs.insert(photo.id).inserted
            else { continue }
            photos.append(photo)
        }

        return photos.sorted(by: DiveActivityMediaPresentation.isOrderedBeforeInGallery)
    }

    @MainActor
    private static func mediaPhotosByID(
        for sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [UUID: DiveMediaPhoto] {
        var byID: [UUID: DiveMediaPhoto] = [:]

        for sighting in sightings {
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaID = sighting.mediaPhotoID
            else { continue }

            if let photo = sighting.mediaPhoto {
                byID[mediaID] = photo
            }
        }

        let neededIDs = Set(
            sightings.compactMap { sighting -> UUID? in
                guard let activityID = sighting.diveActivityID,
                      ownerDiveActivityIDs.contains(activityID)
                else { return nil }
                return sighting.mediaPhotoID
            }
        )
        for mediaID in neededIDs where byID[mediaID] == nil {
            if let photo = fetchMediaPhoto(id: mediaID, modelContext: modelContext) {
                byID[mediaID] = photo
            }
        }

        return byID
    }

    @MainActor
    private static func fetchMediaPhoto(id: UUID, modelContext: ModelContext) -> DiveMediaPhoto? {
        var descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    nonisolated static func timeZoneOffsetByMediaID(
        sightings: [SightingInstance],
        ownerDiveActivityIDs: Set<UUID>,
        timeZoneOffsetByActivityID: [UUID: Int?]
    ) -> [UUID: Int?] {
        guard !ownerDiveActivityIDs.isEmpty else { return [:] }

        var offsets: [UUID: Int?] = [:]
        for sighting in sightings {
            guard let mediaID = sighting.mediaPhotoID,
                  let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  offsets[mediaID] == nil
            else { continue }
            offsets[mediaID] = timeZoneOffsetByActivityID[activityID] ?? nil
        }
        return offsets
    }
}
