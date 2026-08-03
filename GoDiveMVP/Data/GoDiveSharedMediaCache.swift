import CryptoKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Disk LRU for friend-shared media — separate thumb and content namespaces.
actor GoDiveSharedMediaCache {
    static let shared = GoDiveSharedMediaCache()

    enum Tier: String, Sendable {
        case thumb
        case content

        nonisolated var subdirectory: String {
            switch self {
            case .thumb: "thumbs"
            case .content: "content"
            }
        }

        nonisolated var maxBytes: Int64 {
            switch self {
            case .thumb: 50_000_000
            case .content: 500_000_000
            }
        }
    }

    nonisolated static let relativeDirectory = "GoDiveSharedMedia"

    /// Injected by unit tests — when set, cache files live under this root instead of Caches.
    nonisolated(unsafe) static var testingRootDirectory: URL?

    /// Injected by unit tests to exercise LRU eviction with a tiny cap.
    nonisolated(unsafe) static var testingTierMaxBytes: [Tier: Int64]?

    private let fileManager: FileManager
    private let session: URLSession

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.session = session
    }

    func cachedFileURL(remoteURLString: String, tier: Tier) -> URL? {
        guard let fileURL = fileURL(remoteURLString: remoteURLString, tier: tier),
              fileManager.fileExists(atPath: fileURL.path)
        else { return nil }
        touch(fileURL: fileURL)
        return fileURL
    }

    #if canImport(UIKit)
    func image(
        remoteURLString: String,
        tier: Tier,
        allowsNetworkFetch: Bool
    ) async -> UIImage? {
        guard GoDiveSharedMediaCache.sanitizedURL(from: remoteURLString) != nil else { return nil }
        if let cached = cachedFileURL(remoteURLString: remoteURLString, tier: tier),
           let data = try? Data(contentsOf: cached),
           let image = await decodeImage(data: data) {
            return image
        }
        guard allowsNetworkFetch else { return nil }
        guard let data = await fetchData(remoteURLString: remoteURLString) else { return nil }
        guard let stored = try? store(data: data, remoteURLString: remoteURLString, tier: tier) else {
            return await decodeImage(data: data)
        }
        let fileData = (try? Data(contentsOf: stored)) ?? data
        return await decodeImage(data: fileData)
    }
    #endif

    func prefetch(
        remoteURLStrings: [String],
        tier: Tier,
        allowsNetworkFetch: Bool,
        maxConcurrent: Int = 3
    ) async {
        guard allowsNetworkFetch else { return }
        let pending = remoteURLStrings.filter { raw in
            guard Self.sanitizedURL(from: raw) != nil else { return false }
            return cachedFileURL(remoteURLString: raw, tier: tier) == nil
        }
        guard !pending.isEmpty else { return }

        let concurrency = max(1, min(maxConcurrent, pending.count))
        await withTaskGroup(of: Void.self) { group in
            var iterator = pending.makeIterator()
            for _ in 0 ..< concurrency {
                guard let next = iterator.next() else { break }
                group.addTask { await self.prefetchOne(next, tier: tier) }
            }
            for await _ in group {
                guard let next = iterator.next() else { continue }
                group.addTask { await self.prefetchOne(next, tier: tier) }
            }
        }
    }

    /// Local cache file when fully prefetched; otherwise the policy-gated remote URL.
    func resolvedPlaybackURL(remoteURLString: String, tier: Tier = .content) -> URL? {
        if let cached = cachedFileURL(remoteURLString: remoteURLString, tier: tier) {
            return cached
        }
        return Self.streamingURL(from: remoteURLString)
    }

    /// Streaming URL for video — policy-gated remote URL (no full-file download).
    nonisolated static func streamingURL(from remoteURLString: String) -> URL? {
        sanitizedURL(from: remoteURLString)
    }

    /// Test hook — writes bytes without a network fetch.
    func storeForTesting(
        data: Data,
        remoteURLString: String,
        tier: Tier
    ) throws -> URL {
        try store(data: data, remoteURLString: remoteURLString, tier: tier)
    }

    // MARK: - Internals

    nonisolated static func sanitizedURL(from raw: String) -> URL? {
        GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: raw)
    }

    nonisolated static func cacheKey(for remoteURLString: String) -> String {
        let digest = SHA256.hash(data: Data(remoteURLString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func directoryURL(tier: Tier) -> URL? {
        if let testingRoot = Self.testingRootDirectory {
            return testingRoot
                .appendingPathComponent(Self.relativeDirectory, isDirectory: true)
                .appendingPathComponent(tier.subdirectory, isDirectory: true)
        }
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches
            .appendingPathComponent(Self.relativeDirectory, isDirectory: true)
            .appendingPathComponent(tier.subdirectory, isDirectory: true)
    }

    private func fileURL(remoteURLString: String, tier: Tier) -> URL? {
        guard let directory = directoryURL(tier: tier),
              let remote = Self.sanitizedURL(from: remoteURLString)
        else { return nil }
        let ext = fileExtension(for: remote)
        let name = Self.cacheKey(for: remoteURLString)
        return directory.appendingPathComponent("\(name).\(ext)", isDirectory: false)
    }

    private func fileExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty { return ext }
        return "dat"
    }

    private func store(data: Data, remoteURLString: String, tier: Tier) throws -> URL {
        guard let directory = directoryURL(tier: tier),
              let fileURL = fileURL(remoteURLString: remoteURLString, tier: tier)
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        touch(fileURL: fileURL)
        try enforceCapacity(tier: tier)
        return fileURL
    }

    private func prefetchOne(_ raw: String, tier: Tier) async {
        if cachedFileURL(remoteURLString: raw, tier: tier) != nil { return }
        guard let data = await fetchData(remoteURLString: raw) else { return }
        _ = try? store(data: data, remoteURLString: raw, tier: tier)
    }

    private func fetchData(remoteURLString: String) async -> Data? {
        guard let url = Self.sanitizedURL(from: remoteURLString) else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode)
            else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func enforceCapacity(tier: Tier) throws {
        guard let directory = directoryURL(tier: tier) else { return }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        var entries: [(url: URL, size: Int64, date: Date)] = []
        entries.reserveCapacity(urls.count)
        var total: Int64 = 0
        for url in urls {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            total += size
            entries.append((url, size, values.contentModificationDate ?? .distantPast))
        }
        guard total > effectiveMaxBytes(for: tier) else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries {
            guard total > effectiveMaxBytes(for: tier) else { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private func touch(fileURL: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
    }

    private func effectiveMaxBytes(for tier: Tier) -> Int64 {
        if let override = Self.testingTierMaxBytes?[tier] {
            return override
        }
        return tier.maxBytes
    }

    #if canImport(UIKit)
    private func decodeImage(data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
    }
    #endif
}
