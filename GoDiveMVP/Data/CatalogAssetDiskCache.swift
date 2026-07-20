import Foundation

/// On-demand disk cache for Firebase Storage catalog photos / USDZ (Phase 4b).
enum CatalogAssetDiskCache: Sendable {
    enum Kind: String, Sendable {
        case photo
        case model

        nonisolated var subdirectory: String {
            switch self {
            case .photo: "photos"
            case .model: "models"
            }
        }

        nonisolated var pathExtension: String {
            switch self {
            case .photo: "jpg"
            case .model: "usdz"
            }
        }
    }

    nonisolated static let relativeDirectory = "CatalogCDN/Assets"

    nonisolated static func directoryURL(
        kind: Kind,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent("GoDiveMVP", isDirectory: true)
            .appendingPathComponent(relativeDirectory, isDirectory: true)
            .appendingPathComponent(kind.subdirectory, isDirectory: true)
    }

    nonisolated static func fileURL(
        kind: Kind,
        resourceName: String,
        fileManager: FileManager = .default
    ) -> URL? {
        let trimmed = resourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let directory = directoryURL(kind: kind, fileManager: fileManager)
        else {
            return nil
        }
        let base = (trimmed as NSString).deletingPathExtension
        let name = base.isEmpty ? trimmed : base
        return directory.appendingPathComponent("\(name).\(kind.pathExtension)", isDirectory: false)
    }

    nonisolated static func cachedFileURL(
        kind: Kind,
        resourceName: String,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let url = fileURL(kind: kind, resourceName: resourceName, fileManager: fileManager),
              fileManager.fileExists(atPath: url.path)
        else {
            return nil
        }
        return url
    }

    nonisolated static func store(
        data: Data,
        kind: Kind,
        resourceName: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let directory = directoryURL(kind: kind, fileManager: fileManager),
              let fileURL = fileURL(kind: kind, resourceName: resourceName, fileManager: fileManager)
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Downloads when missing; returns local file URL. Soft-fails by throwing.
    static func ensureCached(
        remoteURL: URL,
        kind: Kind,
        resourceName: String,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) async throws -> URL {
        guard GoDiveRemoteURLPolicy.sanitizedCatalogDownloadURL(from: remoteURL.absoluteString) != nil else {
            throw CatalogCDNClientError.invalidURL
        }
        if let existing = cachedFileURL(kind: kind, resourceName: resourceName, fileManager: fileManager) {
            return existing
        }
        let data = try await CatalogCDNClient.fetchData(from: remoteURL, session: session)
        return try store(data: data, kind: kind, resourceName: resourceName, fileManager: fileManager)
    }
}
