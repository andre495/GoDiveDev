import Foundation

/// Spatial + token candidate index over OpenDiveMap reference rows so import matching is
/// **O(candidates)** per dive instead of a full linear scan of ~3k rows.
struct DiveSiteReferenceMatchIndex: Sendable {
    /// ~5.5 km at the equator; neighboring cells cover the auto-link distance bands.
    nonisolated static let gridCellDegrees: Double = 0.05

    private let snapshots: [DiveSiteReferenceSnapshot]
    private let indicesByNormalizedName: [String: [Int]]
    private let indicesByToken: [String: [Int]]
    /// Keys are **`"latBucket,lonBucket"`** (string avoids MainActor-isolated nested `Hashable` under default isolation).
    private let indicesByGridCell: [String: [Int]]

    nonisolated init(reference: [DiveSiteReferenceSnapshot]) {
        snapshots = reference
        var byName: [String: [Int]] = [:]
        var byToken: [String: [Int]] = [:]
        var byCell: [String: [Int]] = [:]
        byName.reserveCapacity(reference.count)
        byToken.reserveCapacity(reference.count * 2)
        byCell.reserveCapacity(reference.count)

        for (index, snapshot) in reference.enumerated() {
            let normalized = DiveSiteCatalogMatcher.normalizedSiteName(snapshot.name)
            if !normalized.isEmpty {
                byName[normalized, default: []].append(index)
                for token in normalized.split(separator: " ") where token.count >= 2 {
                    byToken[String(token), default: []].append(index)
                }
            }
            if let lat = snapshot.latitude, let lon = snapshot.longitude {
                byCell[Self.gridCellKey(latitude: lat, longitude: lon), default: []].append(index)
            }
        }
        indicesByNormalizedName = byName
        indicesByToken = byToken
        indicesByGridCell = byCell
    }

    /// Best match among a reduced candidate set (falls back to a full scan only when candidates are empty).
    nonisolated func bestMatch(
        importName: String?,
        importCoordinate: DiveCoordinate?,
        minimumScore: Double = DiveSiteCatalogMatcher.autoLinkThreshold
    ) -> DiveSiteReferenceMatch? {
        let candidates = candidateIndices(importName: importName, importCoordinate: importCoordinate)
        let pool: [DiveSiteReferenceSnapshot]
        if candidates.isEmpty {
            pool = snapshots
        } else {
            pool = candidates.map { snapshots[$0] }
        }
        return DiveSiteCatalogMatcher.bestReferenceMatch(
            importName: importName,
            importCoordinate: importCoordinate,
            reference: pool,
            minimumScore: minimumScore
        )
    }

    nonisolated func candidateIndices(
        importName: String?,
        importCoordinate: DiveCoordinate?
    ) -> Set<Int> {
        var indices = Set<Int>()

        if let importCoordinate,
           DiveMapCoordinateResolver.isUsable(importCoordinate) {
            let origin = Self.gridBuckets(
                latitude: importCoordinate.latitude,
                longitude: importCoordinate.longitude
            )
            for dLat in -1...1 {
                for dLon in -1...1 {
                    let key = "\(origin.lat + dLat),\(origin.lon + dLon)"
                    if let cellIndices = indicesByGridCell[key] {
                        indices.formUnion(cellIndices)
                    }
                }
            }
        }

        let trimmedName = importName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            let normalized = DiveSiteCatalogMatcher.normalizedSiteName(trimmedName)
            if !normalized.isEmpty {
                if let exact = indicesByNormalizedName[normalized] {
                    indices.formUnion(exact)
                }
                for token in normalized.split(separator: " ") where token.count >= 2 {
                    if let tokenIndices = indicesByToken[String(token)] {
                        indices.formUnion(tokenIndices)
                    }
                }
            }
        }

        return indices
    }

    private nonisolated static func gridBuckets(
        latitude: Double,
        longitude: Double
    ) -> (lat: Int, lon: Int) {
        let cell = gridCellDegrees
        return (lat: Int(floor(latitude / cell)), lon: Int(floor(longitude / cell)))
    }

    private nonisolated static func gridCellKey(latitude: Double, longitude: Double) -> String {
        let buckets = gridBuckets(latitude: latitude, longitude: longitude)
        return "\(buckets.lat),\(buckets.lon)"
    }
}

extension DiveSiteReferenceCatalog {
    private nonisolated(unsafe) static var cachedMatchIndex: DiveSiteReferenceMatchIndex?
    private nonisolated static let matchIndexLock = NSLock()

    /// Cached match index over **`bundledReference()`** (invalidated with the snapshot caches).
    nonisolated static func bundledMatchIndex(
        bundle: Bundle = .main,
        resourceExtension: String = "json"
    ) -> DiveSiteReferenceMatchIndex {
        matchIndexLock.lock()
        if let cachedMatchIndex {
            matchIndexLock.unlock()
            return cachedMatchIndex
        }
        matchIndexLock.unlock()

        let index = DiveSiteReferenceMatchIndex(
            reference: bundledReference(bundle: bundle, resourceExtension: resourceExtension)
        )
        matchIndexLock.lock()
        cachedMatchIndex = index
        matchIndexLock.unlock()
        return index
    }

    /// Clears the match-index cache when snapshot caches are invalidated.
    nonisolated static func invalidateMatchIndexCache() {
        matchIndexLock.lock()
        cachedMatchIndex = nil
        matchIndexLock.unlock()
    }
}
