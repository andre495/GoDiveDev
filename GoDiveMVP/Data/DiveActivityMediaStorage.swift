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
        to activity: DiveActivity,
        modelContext: ModelContext
    ) throws -> UUID {
        let mediaID = UUID()
        let sortOrder = nextSortOrder(on: activity)

        let row: DiveMediaPhoto
        switch payload {
        case .image(let data):
            row = DiveMediaPhoto(
                id: mediaID,
                sortOrder: sortOrder,
                mediaKind: .image,
                mediaData: preparedImageData(data),
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
                dive: activity
            )
        }

        activity.mediaPhotos.append(row)
        modelContext.insert(row)
        try modelContext.save()
        return mediaID
    }

    /// Removes on-disk video files for a dive before the parent row is deleted.
    static func deleteMediaFiles(forDiveID diveID: UUID, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate { $0.diveActivityID == diveID }
        )
        let items = try modelContext.fetch(descriptor)
        DiveMediaFileStore.deleteFiles(for: items)
    }
}
