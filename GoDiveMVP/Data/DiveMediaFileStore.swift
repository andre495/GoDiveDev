import Foundation
import UniformTypeIdentifiers

/// On-disk dive videos (images stay inline in SwiftData **`mediaData`**).
enum DiveMediaFileStore: Sendable {

    private nonisolated static let folderName = "DiveMedia"

    nonisolated static func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated static func fileURL(fileName: String) -> URL? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? directoryURL().appendingPathComponent(trimmed)
    }

    /// Copies a picker temp file into app storage; returns stored file name (e.g. **`{uuid}.mov`**).
    nonisolated static func importVideo(from sourceURL: URL, mediaID: UUID) throws -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let fileName = "\(mediaID.uuidString).\(ext)"
        let destination = try directoryURL().appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    nonisolated static func deleteFileIfNeeded(fileName: String) {
        guard let url = fileURL(fileName: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated static func deleteFiles(named fileNames: [String]) {
        for fileName in fileNames {
            deleteFileIfNeeded(fileName: fileName)
        }
    }
}
