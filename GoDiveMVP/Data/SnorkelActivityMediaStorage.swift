import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

enum SnorkelActivityMediaStorage {

    @discardableResult
    static func addLibraryReference(
        localIdentifier: String,
        mediaKind: DiveMediaKind,
        capturedAt: Date? = nil,
        to activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws -> UUID {
        let trimmedLocal = localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(Photos)
        let cloudIdentifier = DiveMediaCloudIdentifierResolver.cloudIdentifierString(
            forLocalIdentifier: trimmedLocal
        ) ?? ""
        #else
        let cloudIdentifier = ""
        #endif
        let mediaID = UUID()
        let sortOrder = activity.mediaPhotos.count
        let row = SnorkelMediaPhoto(
            id: mediaID,
            sortOrder: sortOrder,
            mediaKind: mediaKind,
            capturedAt: capturedAt,
            photosLocalIdentifier: trimmedLocal,
            photosCloudIdentifier: cloudIdentifier,
            snorkelActivity: activity
        )
        activity.mediaPhotos.append(row)
        modelContext.insert(row)
        try modelContext.save()
        NotificationCenter.default.post(name: .diveActivityMediaDidChange, object: nil)
        #if canImport(UIKit)
        Task { @MainActor in
            await SnorkelMediaPreviewStorage.captureAndPersistPreview(for: row, modelContext: modelContext)
        }
        #endif
        return mediaID
    }

    nonisolated static func shouldReferenceLibraryAsset(localIdentifier: String?) -> Bool {
        DiveActivityMediaStorage.shouldReferenceLibraryAsset(localIdentifier: localIdentifier)
    }

    static func setFeaturedMedia(
        _ mediaID: UUID?,
        on activity: SnorkelActivity,
        modelContext: ModelContext
    ) throws {
        guard activity.featuredMediaPhotoID != mediaID else { return }
        activity.featuredMediaPhotoID = mediaID
        try modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
    }

    /// Detaches one gallery item from the snorkel: marine-life tags, buddy tags, featured pointer, and share selection.
    static func removeMedia(
        _ media: SnorkelMediaPhoto,
        from activity: SnorkelActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) throws {
        let mediaID = media.id

        let sightings = try MarineLifeSightingRecorder.sightings(
            forSnorkelActivityID: activity.id,
            modelContext: modelContext
        ).filter { $0.snorkelMediaPhotoID == mediaID }
        if let owner {
            for marineLifeUUID in Set(sightings.map(\.marineLifeUUID)) {
                try MarineLifeSightingRecorder.untagSpecies(
                    marineLifeUUID: marineLifeUUID,
                    on: media,
                    snorkel: activity,
                    owner: owner,
                    modelContext: modelContext
                )
            }
        } else {
            for row in sightings {
                modelContext.delete(row)
            }
        }

        let buddyIDs = try SnorkelMediaBuddyAssociation.tags(
            forMediaPhotoID: mediaID,
            modelContext: modelContext
        ).compactMap(\.buddyID)
        for buddyID in buddyIDs {
            try SnorkelMediaBuddyAssociation.removeBuddyTag(
                buddyID: buddyID,
                from: media,
                snorkel: activity,
                modelContext: modelContext
            )
        }

        if activity.featuredMediaPhotoID == mediaID {
            activity.featuredMediaPhotoID = nil
        }

        var shareIDs = ActivityFriendShareConfiguration.decodeMediaIDs(
            from: activity.friendShareMediaSelectedIDsJSON
        )
        if shareIDs.contains(mediaID) {
            shareIDs.remove(mediaID)
            activity.friendShareMediaSelectedIDsJSON = ActivityFriendShareConfiguration.encodeMediaIDs(shareIDs)
        }

        activity.mediaPhotos.removeAll { $0.id == mediaID }
        modelContext.delete(media)
        try modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
    }
}
