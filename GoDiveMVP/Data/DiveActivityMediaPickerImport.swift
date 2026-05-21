import Foundation
import PhotosUI
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
