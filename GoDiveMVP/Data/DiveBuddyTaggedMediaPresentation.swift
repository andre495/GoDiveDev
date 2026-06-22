import Foundation
import SwiftData

/// Tagged dive media for **`ViewDiveBuddyDetails`** (photos/videos where the buddy is tagged).
enum DiveBuddyTaggedMediaPresentation {

    static let sectionTitle = "Your tagged photos"

    struct GalleryPayload: Equatable, Sendable {
        let mediaItemIDs: [UUID]
        let timeZoneOffsetByMediaID: [UUID: Int?]
    }

    nonisolated static func galleryRefreshToken(
        tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>
    ) -> String {
        let firstTagID = tags.first?.id.uuidString ?? ""
        let lastMediaID = tags.compactMap(\.mediaPhotoID).last?.uuidString ?? ""
        return "\(tags.count)|\(firstTagID)|\(lastMediaID)|\(ownerDiveActivityIDs.count)"
    }

    nonisolated static func galleryPayload(
        tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>,
        timeZoneOffsetByActivityID: [UUID: Int?]
    ) -> GalleryPayload {
        let photos = taggedMediaPhotos(
            tags: tags,
            ownerDiveActivityIDs: ownerDiveActivityIDs
        )
        return GalleryPayload(
            mediaItemIDs: photos.map(\.id),
            timeZoneOffsetByMediaID: timeZoneOffsetByMediaID(
                tags: tags,
                ownerDiveActivityIDs: ownerDiveActivityIDs,
                timeZoneOffsetByActivityID: timeZoneOffsetByActivityID
            )
        )
    }

    /// Unique **`DiveMediaPhoto`** rows for the signed-in user's dives, gallery order (oldest capture first).
    nonisolated static func taggedMediaPhotos(
        tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>
    ) -> [DiveMediaPhoto] {
        guard !ownerDiveActivityIDs.isEmpty else { return [] }

        var seenPhotoIDs = Set<UUID>()
        var photos: [DiveMediaPhoto] = []

        for tag in tags {
            guard let activityID = tag.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let photo = tag.mediaPhoto,
                  seenPhotoIDs.insert(photo.id).inserted
            else { continue }
            photos.append(photo)
        }

        return photos.sorted(by: DiveActivityMediaPresentation.isOrderedBeforeInGallery)
    }

    /// Resolves photos by **`mediaPhotoID`** when the SwiftData relationship is not faulted in.
    @MainActor
    static func resolvedTaggedMediaPhotos(
        tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [DiveMediaPhoto] {
        guard !ownerDiveActivityIDs.isEmpty else { return [] }

        let mediaByID = mediaPhotosByID(
            for: tags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )

        var seenPhotoIDs = Set<UUID>()
        var photos: [DiveMediaPhoto] = []

        for tag in tags {
            guard let activityID = tag.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaID = tag.mediaPhotoID,
                  let photo = mediaByID[mediaID],
                  seenPhotoIDs.insert(photo.id).inserted
            else { continue }
            photos.append(photo)
        }

        return photos.sorted(by: DiveActivityMediaPresentation.isOrderedBeforeInGallery)
    }

    @MainActor
    private static func mediaPhotosByID(
        for tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [UUID: DiveMediaPhoto] {
        var byID: [UUID: DiveMediaPhoto] = [:]

        for tag in tags {
            guard let activityID = tag.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaID = tag.mediaPhotoID
            else { continue }

            if let photo = tag.mediaPhoto {
                byID[mediaID] = photo
            }
        }

        let neededIDs = Set(
            tags.compactMap { tag -> UUID? in
                guard let activityID = tag.diveActivityID,
                      ownerDiveActivityIDs.contains(activityID)
                else { return nil }
                return tag.mediaPhotoID
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
        tags: [DiveMediaBuddyTag],
        ownerDiveActivityIDs: Set<UUID>,
        timeZoneOffsetByActivityID: [UUID: Int?]
    ) -> [UUID: Int?] {
        guard !ownerDiveActivityIDs.isEmpty else { return [:] }

        var offsets: [UUID: Int?] = [:]
        for tag in tags {
            guard let mediaID = tag.mediaPhotoID,
                  let activityID = tag.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  offsets[mediaID] == nil
            else { continue }
            offsets[mediaID] = timeZoneOffsetByActivityID[activityID] ?? nil
        }
        return offsets
    }
}
