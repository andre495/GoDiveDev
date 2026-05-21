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

    static func loadPayload(from item: PhotosPickerItem) async throws -> DiveMediaImportPayload {
        if isVideoItem(item) {
            guard let picked = try await item.loadTransferable(type: PickedVideoFile.self) else {
                throw DiveMediaImportError.unsupportedItem
            }
            return .video(picked.url)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw DiveMediaImportError.unsupportedItem
        }
        return .image(data)
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

            let payload: DiveMediaImportPayload
            do {
                payload = try await DiveActivityMediaPickerImport.loadPayload(from: item)
            } catch {
                continue
            }

            onProgress?(savedCount, total, DiveMediaImportProgressPresentation.savingStage(itemIndex: itemIndex, total: total))
            await Task.yield()

            do {
                let addedID = try DiveActivityMediaStorage.addMedia(
                    payload,
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
