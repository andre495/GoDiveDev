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
}
