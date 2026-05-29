import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// **`PhotosPicker`** item classification (image vs video) for reference attachment.
enum DiveActivityMediaPickerImport: Sendable {

    nonisolated static func isVideoItem(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { type in
            type.conforms(to: .movie) || type.conforms(to: .video)
        }
    }
}

/// Imports multiple **`PhotosPicker`** items onto a dive as Photos-library references (no copied bytes).
enum DiveActivityMediaBatchImport {
    struct Outcome: Sendable {
        let savedCount: Int
        let lastAddedMediaID: UUID?
        let failureMessage: String?
    }

    typealias ProgressHandler = @MainActor (_ completed: Int, _ total: Int, _ stage: String) -> Void

    @MainActor
    static func importPickerItems(
        _ items: [PhotosPickerItem],
        into activity: DiveActivity,
        modelContext: ModelContext,
        onProgress: ProgressHandler? = nil
    ) async -> Outcome {
        let total = items.count
        guard total > 0 else {
            return Outcome(savedCount: 0, lastAddedMediaID: nil, failureMessage: nil)
        }

        var savedCount = 0
        var lastAddedID: UUID?

        for (index, item) in items.enumerated() {
            let itemIndex = index + 1
            onProgress?(savedCount, total, DiveMediaImportProgressPresentation.loadingStage(itemIndex: itemIndex, total: total))
            await Task.yield()

            // Photos picker items carry a `PHAsset.localIdentifier` (picker uses `photoLibrary: .shared()`);
            // store a pointer to the original instead of copying its bytes. Skip anything without an identifier.
            guard DiveActivityMediaStorage.shouldReferenceLibraryAsset(localIdentifier: item.itemIdentifier),
                  let identifier = item.itemIdentifier else {
                continue
            }

            onProgress?(savedCount, total, DiveMediaImportProgressPresentation.savingStage(itemIndex: itemIndex, total: total))
            await Task.yield()

            do {
                let kind: DiveMediaKind = DiveActivityMediaPickerImport.isVideoItem(item) ? .video : .image
                let capturedAt = await DiveMediaReferenceLoader.creationDate(localIdentifier: identifier)
                let addedID = try DiveActivityMediaStorage.addLibraryReference(
                    localIdentifier: identifier,
                    mediaKind: kind,
                    capturedAt: capturedAt,
                    to: activity,
                    modelContext: modelContext
                )
                lastAddedID = addedID
                savedCount += 1
                onProgress?(savedCount, total, DiveMediaImportProgressPresentation.savingStage(itemIndex: itemIndex, total: total))
            } catch {
                return Outcome(
                    savedCount: savedCount,
                    lastAddedMediaID: lastAddedID,
                    failureMessage: error.localizedDescription
                )
            }
        }

        if savedCount == 0 {
            return Outcome(
                savedCount: 0,
                lastAddedMediaID: nil,
                failureMessage: DiveMediaImportProgressPresentation.failureMessageWhenNoneSaved(attempted: total)
            )
        }

        return Outcome(savedCount: savedCount, lastAddedMediaID: lastAddedID, failureMessage: nil)
    }
}
