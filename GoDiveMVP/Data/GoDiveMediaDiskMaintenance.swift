import Foundation

/// Caps and reclaims ephemeral media bytes so Photos / friend-share content is not long-term app data.
enum GoDiveMediaDiskMaintenance: Sendable {

    nonisolated static let sharedURLCacheMemoryBytes = 4 * 1_024 * 1_024
    nonisolated static let sharedURLCacheDiskBytes = 20 * 1_024 * 1_024

    nonisolated static let temporaryExportFilenamePrefixes = [
        "godive-shared-media-",
        "godive-profile-hero-",
    ]

    /// Call once at process start so **`URLSession.shared`** cannot grow an unbounded HTTP disk cache.
    nonisolated static func installSharedURLCacheLimits() {
        URLCache.shared = URLCache(
            memoryCapacity: sharedURLCacheMemoryBytes,
            diskCapacity: sharedURLCacheDiskBytes
        )
    }

    nonisolated static func isEphemeralExportTemporaryURL(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return temporaryExportFilenamePrefixes.contains { name.hasPrefix($0) }
    }

    /// Drops friend-share **content** files, leftover export temps, and the shared HTTP cache.
    /// Thumbnails stay (small LRU). Safe on launch and when the app backgrounds.
    static func reclaimEphemeralMediaCaches(
        fileManager: FileManager = .default
    ) async {
        URLCache.shared.removeAllCachedResponses()
        await GoDiveSharedMediaCache.shared.purge(tier: .content)
        removeTemporaryExportFiles(fileManager: fileManager)
    }

    nonisolated static func removeTemporaryExportFiles(fileManager: FileManager = .default) {
        let tmp = fileManager.temporaryDirectory
        let urls = (try? fileManager.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in urls where isEphemeralExportTemporaryURL(url) {
            try? fileManager.removeItem(at: url)
        }
    }
}
