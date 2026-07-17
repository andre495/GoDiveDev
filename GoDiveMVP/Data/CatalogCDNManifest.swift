import Foundation

/// Phase 4 CDN manifest (`catalog/v1/manifest.json`) — Firebase Hosting.
nonisolated struct CatalogCDNManifest: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var catalogVersion: Int
    var minimumAppVersion: String
    var generatedAt: String?
    var marineLife: MarineLifePayload?

    nonisolated struct MarineLifePayload: Codable, Equatable, Sendable {
        var format: String
        var path: String
        var sha256: String
        var itemCount: Int?

        enum CodingKeys: String, CodingKey {
            case format, path, sha256, itemCount
        }
    }
}

enum CatalogCDNManifestCodec: Sendable {
    nonisolated static func decode(_ data: Data) throws -> CatalogCDNManifest {
        let decoder = JSONDecoder()
        return try decoder.decode(CatalogCDNManifest.self, from: data)
    }

    nonisolated static func encode(_ manifest: CatalogCDNManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(manifest)
    }
}

/// Pure gates for whether a CDN refresh should run.
enum CatalogCDNRefreshPolicy: Sendable {
    /// **`true`** when remote catalog is newer than the last applied version.
    nonisolated static func shouldApply(
        remoteCatalogVersion: Int,
        appliedCatalogVersion: Int
    ) -> Bool {
        remoteCatalogVersion > appliedCatalogVersion
    }

    /// **`true`** when this app build meets the manifest minimum (numeric dotted segments).
    nonisolated static func meetsMinimumAppVersion(
        appVersion: String,
        minimumAppVersion: String
    ) -> Bool {
        compareDottedVersions(appVersion, minimumAppVersion) != .orderedAscending
    }

    nonisolated static func compareDottedVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0 ..< count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }
}
