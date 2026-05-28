import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum DiveMediaImportError: Error, Sendable {
    case unsupportedItem
}

enum DiveMediaImportPayload: Sendable {
    case image(Data)
    case video(URL)
}

struct LoadedDiveMedia: Sendable {
    var payload: DiveMediaImportPayload
    var capturedAt: Date?
}

/// **`PhotosPicker`** → image bytes or copied video file URL.
enum DiveActivityMediaPickerImport: Sendable {

    struct PickedVideoFile: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .movie) { video in
                SentTransferredFile(video.url)
            } importing: { received in
                let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: received.file, to: destination)
                return PickedVideoFile(url: destination)
            }
        }
    }

    nonisolated static func isVideoItem(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { type in
            type.conforms(to: .movie) || type.conforms(to: .video)
        }
    }

    static func load(from item: PhotosPickerItem) async throws -> LoadedDiveMedia {
        if isVideoItem(item) {
            guard let picked = try await item.loadTransferable(type: PickedVideoFile.self) else {
                throw DiveMediaImportError.unsupportedItem
            }
            let capturedAt = await DiveMediaCaptureDateExtraction.resolveVideoCaptureDate(
                fileURL: picked.url,
                photosLocalIdentifier: item.itemIdentifier
            )
            return LoadedDiveMedia(payload: .video(picked.url), capturedAt: capturedAt)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw DiveMediaImportError.unsupportedItem
        }
        let capturedAt = await DiveMediaCaptureDateExtraction.resolveImageCaptureDate(
            data: data,
            photosLocalIdentifier: item.itemIdentifier
        )
        return LoadedDiveMedia(payload: .image(data), capturedAt: capturedAt)
    }
}

/// Imports multiple **`PhotosPicker`** items onto a dive with progress callbacks.
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

            let loaded: LoadedDiveMedia
            do {
                loaded = try await DiveActivityMediaPickerImport.load(from: item)
            } catch {
                continue
            }

            onProgress?(savedCount, total, DiveMediaImportProgressPresentation.savingStage(itemIndex: itemIndex, total: total))
            await Task.yield()

            do {
                let addedID = try DiveActivityMediaStorage.addMedia(
                    loaded.payload,
                    capturedAt: loaded.capturedAt,
                    photosLocalIdentifier: item.itemIdentifier,
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
