import Foundation

/// On-disk OpenDiveMap reference JSON from Firebase Hosting (Phase 4b).
enum DiveSiteReferenceCDNCache: Sendable {
    nonisolated static let fileName = "dive_sites.json"
    nonisolated static let relativeDirectory = "CatalogCDN"

    nonisolated static func directoryURL(
        fileManager: FileManager = .default
    ) -> URL? {
        guard let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent("GoDiveMVP", isDirectory: true)
            .appendingPathComponent(relativeDirectory, isDirectory: true)
    }

    nonisolated static func fileURL(fileManager: FileManager = .default) -> URL? {
        directoryURL(fileManager: fileManager)?.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Writes verified CDN payload and clears the in-memory reference caches.
    nonisolated static func store(
        data: Data,
        fileManager: FileManager = .default
    ) throws {
        guard let directory = directoryURL(fileManager: fileManager),
              let fileURL = fileURL(fileManager: fileManager)
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        DiveSiteReferenceCatalog.invalidateCaches()
    }

    nonisolated static func loadData(fileManager: FileManager = .default) -> Data? {
        guard let fileURL = fileURL(fileManager: fileManager),
              fileManager.fileExists(atPath: fileURL.path)
        else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    #if DEBUG
    nonisolated static func removeForTesting(fileManager: FileManager = .default) {
        if let fileURL = fileURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: fileURL)
        }
        DiveSiteReferenceCatalog.invalidateCaches()
    }
    #endif
}
