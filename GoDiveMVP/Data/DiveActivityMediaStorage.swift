import Foundation
import SwiftData
#if canImport(Photos)
import Photos
#endif

extension Notification.Name {
    /// Posted after a dive's media set changes (reference added or pruned), so the logbook can rebuild its
    /// row cache and surface the new preview thumbnail right away.
    ///
    /// **`nonisolated`** so **`postMediaDidChange()`** can reference it from a nonisolated context
    /// (the app uses MainActor default isolation).
    nonisolated static let diveActivityMediaDidChange = Notification.Name("GoDive.diveActivityMediaDidChange")
}

/// Persists **`DiveMediaPhoto`** rows on a **`DiveActivity`**. All media is a **pointer** to a Photos-library asset
/// (no duplicated bytes) — see **`DiveMediaReferenceLoader`** for on-demand loading.
enum DiveActivityMediaStorage {

    /// Next **`sortOrder`** after existing **`mediaPhotos`**.
    @MainActor
    static func nextSortOrder(on activity: DiveActivity) -> Int {
        DiveActivityMediaPresentation.nextSortOrder(on: activity)
    }

    /// **`true`** when a picked / matched item carries a usable **`PHAsset.localIdentifier`** to reference.
    nonisolated static func shouldReferenceLibraryAsset(localIdentifier: String?) -> Bool {
        guard let trimmed = localIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !trimmed.isEmpty
    }

    /// Persists a **pointer** to a Photos-library asset (no byte copy): pixels/frames load on demand via
    /// **`DiveMediaReferenceLoader`**. Used by auto-attach and the manual picker.
    @discardableResult
    static func addLibraryReference(
        localIdentifier: String,
        mediaKind: DiveMediaKind,
        capturedAt: Date? = nil,
        to activity: DiveActivity,
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
        let row = DiveMediaPhoto(
            id: mediaID,
            sortOrder: nextSortOrder(on: activity),
            mediaKind: mediaKind,
            capturedAt: capturedAt,
            photosLocalIdentifier: trimmedLocal,
            photosCloudIdentifier: cloudIdentifier,
            dive: activity
        )
        activity.mediaPhotos.append(row)
        modelContext.insert(row)
        try modelContext.save()
        postMediaDidChange()
        #if canImport(UIKit)
        Task { @MainActor in
            await DiveMediaPreviewStorage.captureAndPersistPreview(for: row, modelContext: modelContext)
        }
        #endif
        return mediaID
    }

    /// Sets (or clears, when **`nil`**) the user-chosen **featured** media for the logbook row preview, then saves
    /// and notifies observers so the logbook thumbnail updates right away. Clearing reverts to the default (oldest).
    static func setFeaturedMedia(
        _ mediaID: UUID?,
        on activity: DiveActivity,
        modelContext: ModelContext
    ) throws {
        guard activity.featuredMediaPhotoID != mediaID else { return }
        activity.featuredMediaPhotoID = mediaID
        try modelContext.save()
        postMediaDidChange()
    }

    /// Detaches one gallery item from the dive: marine-life tags, buddy tags, featured pointer, and share selection.
    static func removeMedia(
        _ media: DiveMediaPhoto,
        from activity: DiveActivity,
        owner: UserProfile?,
        modelContext: ModelContext
    ) throws {
        let mediaID = media.id

        let sightings = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: mediaID,
            modelContext: modelContext
        )
        if let owner {
            for marineLifeUUID in Set(sightings.map(\.marineLifeUUID)) {
                try MarineLifeSightingRecorder.untagSpecies(
                    marineLifeUUID: marineLifeUUID,
                    on: media,
                    dive: activity,
                    owner: owner,
                    modelContext: modelContext
                )
            }
        } else {
            for row in sightings {
                modelContext.delete(row)
            }
        }

        let buddyIDs = try DiveMediaBuddyAssociation.tags(
            forMediaPhotoID: mediaID,
            modelContext: modelContext
        ).compactMap(\.buddyID)
        for buddyID in buddyIDs {
            try DiveMediaBuddyAssociation.removeBuddyTag(
                buddyID: buddyID,
                from: media,
                dive: activity,
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
        postMediaDidChange()
    }

    /// Notifies observers (e.g. the logbook row cache) that a dive's media set changed.
    /// Coalesced downstream, so per-photo posts during bulk auto-attach collapse into one refresh.
    nonisolated static func postMediaDidChange() {
        NotificationCenter.default.post(name: .diveActivityMediaDidChange, object: nil)
    }
}
