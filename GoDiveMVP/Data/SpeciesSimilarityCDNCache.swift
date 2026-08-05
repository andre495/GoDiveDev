import Foundation

/// Community sighting-similarity cache published by the scheduled Cloud Function (Storage + optional Hosting).
nonisolated struct SpeciesSimilarityCacheDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var updatedAt: String?
    var bySpecies: [String: [Entry]]

    struct Entry: Codable, Equatable, Sendable {
        var uuid: String
        var sightingScore: Double
        var evidence: [Evidence]?

        struct Evidence: Codable, Equatable, Sendable {
            var signal: String
            var weight: Double
            var detail: String?
        }
    }
}

nonisolated struct SpeciesSimilarityMetaDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int?
    var path: String?
    var sha256: String
    var updatedAt: String?
}

enum SpeciesSimilarityCDNCache: Sendable {
    nonisolated static let relativePath = "catalog/v1/species_similarity.json"
    nonisolated static let metaRelativePath = "catalog/v1/species_similarity.meta.json"
    nonisolated static let cacheFileName = "species_similarity.json"
    nonisolated static let appliedShaDefaultsKey = "godive.speciesSimilarity.appliedSha256"
    nonisolated static let defaultStorageBucket = "godive-1cff8.firebasestorage.app"

    nonisolated static func storageDownloadURL(
        relativePath: String,
        bucket: String = defaultStorageBucket
    ) -> URL? {
        let trimmed = relativePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard CatalogCDNPathValidation.isAllowedRelativePath(trimmed) else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = trimmed
            .split(separator: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0) }
            .joined(separator: "%2F")
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(encoded)?alt=media")
    }

    nonisolated static func cacheDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("CatalogCDN", isDirectory: true)
    }

    nonisolated static func cacheFileURL(fileManager: FileManager = .default) -> URL {
        cacheDirectory(fileManager: fileManager).appendingPathComponent(cacheFileName)
    }

    nonisolated static func loadCachedDocument(
        fileManager: FileManager = .default
    ) -> SpeciesSimilarityCacheDocument? {
        let url = cacheFileURL(fileManager: fileManager)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SpeciesSimilarityCacheDocument.self, from: data)
    }

    nonisolated static func sightingScores(
        forSeedUUID seedUUID: String,
        document: SpeciesSimilarityCacheDocument?
    ) -> [String: Double] {
        guard let rows = document?.bySpecies[seedUUID] else { return [:] }
        var out: [String: Double] = [:]
        for row in rows where row.sightingScore > 0 {
            out[row.uuid] = row.sightingScore
        }
        return out
    }

    /// Soft-fail refresh from Storage (primary) then optional Hosting base URL.
    @discardableResult
    static func refreshIfNeeded(
        hostingBaseURL: URL? = CatalogCDNSecretsBootstrap.loadManifestBaseURL(),
        storageBucket: String = defaultStorageBucket,
        userDefaults: UserDefaults = .standard,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) async -> Bool {
        let metaURL = storageDownloadURL(relativePath: metaRelativePath, bucket: storageBucket)
        let payloadURL = storageDownloadURL(relativePath: relativePath, bucket: storageBucket)
            ?? hostingBaseURL.flatMap {
                CatalogCDNClient.url(base: $0, relativePath: relativePath)
            }
        guard let payloadURL else { return false }

        do {
            var expectedSha: String?
            if let metaURL {
                let (metaData, _) = try await session.data(from: metaURL)
                if let meta = try? JSONDecoder().decode(SpeciesSimilarityMetaDocument.self, from: metaData) {
                    expectedSha = meta.sha256.lowercased()
                    let applied = (userDefaults.string(forKey: appliedShaDefaultsKey) ?? "").lowercased()
                    if !expectedSha!.isEmpty, expectedSha == applied,
                       fileManager.fileExists(atPath: cacheFileURL(fileManager: fileManager).path) {
                        return false
                    }
                }
            }

            let (data, _) = try await session.data(from: payloadURL)
            if let expectedSha, !expectedSha.isEmpty {
                guard CatalogCDNChecksum.matches(data: data, expectedHex: expectedSha) else {
                    GoDiveSecurityEvent.record(.cdnChecksumMismatch, detail: "speciesSimilarity")
                    return false
                }
            }
            _ = try JSONDecoder().decode(SpeciesSimilarityCacheDocument.self, from: data)
            let dir = cacheDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: cacheFileURL(fileManager: fileManager), options: .atomic)
            if let expectedSha, !expectedSha.isEmpty {
                userDefaults.set(expectedSha, forKey: appliedShaDefaultsKey)
            } else {
                userDefaults.set(CatalogCDNChecksum.sha256Hex(data), forKey: appliedShaDefaultsKey)
            }
            return true
        } catch {
            return false
        }
    }

    #if DEBUG
    static func resetForTesting(userDefaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        userDefaults.removeObject(forKey: appliedShaDefaultsKey)
        try? fileManager.removeItem(at: cacheFileURL(fileManager: fileManager))
    }
    #endif
}
