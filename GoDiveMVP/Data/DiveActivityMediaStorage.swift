import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Persists **`DiveMediaPhoto`** rows on a **`DiveActivity`** (picker / import).
enum DiveActivityMediaStorage {

    /// Next **`sortOrder`** after existing **`mediaPhotos`**.
    nonisolated static func nextSortOrder(on activity: DiveActivity) -> Int {
        DiveActivityMediaPresentation.nextSortOrder(on: activity)
    }

    /// JPEG when possible; otherwise raw picker bytes.
    nonisolated static func preparedImageData(_ raw: Data) -> Data {
        #if canImport(UIKit)
        if let image = UIImage(data: raw), let jpeg = image.jpegData(compressionQuality: 0.85) {
            return jpeg
        }
        #endif
        return raw
    }

    @discardableResult
    static func addMedia(
        _ payload: DiveMediaImportPayload,
        capturedAt: Date? = nil,
        photosLocalIdentifier: String? = nil,
        to activity: DiveActivity,
        modelContext: ModelContext
    ) throws -> UUID {
        let mediaID = UUID()
        let sortOrder = nextSortOrder(on: activity)

        let libraryID = photosLocalIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let row: DiveMediaPhoto
        switch payload {
        case .image(let data):
            row = DiveMediaPhoto(
                id: mediaID,
                sortOrder: sortOrder,
                mediaKind: .image,
                mediaData: preparedImageData(data),
                capturedAt: capturedAt,
                photosLocalIdentifier: libraryID,
                dive: activity
            )
        case .video(let sourceURL):
            let fileName = try DiveMediaFileStore.importVideo(from: sourceURL, mediaID: mediaID)
            row = DiveMediaPhoto(
                id: mediaID,
                sortOrder: sortOrder,
                mediaKind: .video,
                mediaData: Data(),
                mediaFileName: fileName,
                capturedAt: capturedAt,
                photosLocalIdentifier: libraryID,
                dive: activity
            )
        }

        activity.mediaPhotos.append(row)
        modelContext.insert(row)
        try modelContext.save()
        return mediaID
    }

    /// Removes on-disk video files for a dive before the parent row is deleted.
    ///
    /// **`nonisolated`** so **`DiveBackgroundDeletionWorker`** (**`@ModelActor`**) can call this without hopping to the main actor.
    nonisolated static func deleteMediaFiles(forDiveID diveID: UUID, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate { $0.diveActivityID == diveID }
        )
        let items = try modelContext.fetch(descriptor)
        let videoFileNames = items.compactMap { item -> String? in
            guard item.mediaKind == DiveMediaKind.video.rawValue else { return nil }
            let name = item.mediaFileName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        DiveMediaFileStore.deleteFiles(named: videoFileNames)
    }
}
