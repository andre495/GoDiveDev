import Foundation

/// One OpenDiveMap row from bundled reference JSON (read-only; not a SwiftData model).
struct DiveSiteReferenceSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let country: String
    let countryCode: String
    let latitude: Double?
    let longitude: Double?
    let maxDepthMeters: Int?
    let entry: String
    let environment: String
    let topologies: [String]
    let seaName: String
}

/// Loads bundled OpenDiveMap reference rows for import matching (lazy, in-memory cache).
enum DiveSiteReferenceCatalog: Sendable {
    nonisolated static let bundledResourceName = "opendivemap_dive_sites_reference"

    /// Lock-guarded caches so the ~3,100-row JSON decode can be warmed **off the main actor**
    /// (search-index prewarm) while main-thread callers safely read the shared cache.
    private nonisolated(unsafe) static var cachedSnapshots: [DiveSiteReferenceSnapshot]?
    private nonisolated(unsafe) static var cachedSnapshotsByID: [String: DiveSiteReferenceSnapshot]?
    private nonisolated static let cacheLock = NSLock()

    nonisolated static func bundledReference(
        bundle: Bundle = .main,
        resourceExtension: String = "json"
    ) -> [DiveSiteReferenceSnapshot] {
        cacheLock.lock()
        if let cachedSnapshots {
            cacheLock.unlock()
            return cachedSnapshots
        }
        cacheLock.unlock()

        guard let fileURL = bundle.url(
            forResource: bundledResourceName,
            withExtension: resourceExtension
        ) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            // Decode outside the lock so a concurrent caller is never blocked for the full decode;
            // a rare race just decodes twice and both store identical results.
            let decoded = try JSONDecoder().decode([DiveSiteReferenceSnapshot].self, from: data)
            cacheLock.lock()
            cachedSnapshots = decoded
            cacheLock.unlock()
            return decoded
        } catch {
            return []
        }
    }

    /// Reference rows keyed by OpenDiveMap id, built (and cached) once. Use this for per-row lookups —
    /// scanning `bundledReference()` with `first(where:)` per row is O(n) over thousands of rows and was
    /// a major source of search-results scroll lag.
    nonisolated static func bundledReferenceByID(
        bundle: Bundle = .main,
        resourceExtension: String = "json"
    ) -> [String: DiveSiteReferenceSnapshot] {
        cacheLock.lock()
        if let cachedSnapshotsByID {
            cacheLock.unlock()
            return cachedSnapshotsByID
        }
        cacheLock.unlock()

        let byID = Dictionary(
            bundledReference(bundle: bundle, resourceExtension: resourceExtension).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        cacheLock.lock()
        cachedSnapshotsByID = byID
        cacheLock.unlock()
        return byID
    }

    #if DEBUG
    nonisolated static func resetCacheForTesting() {
        cacheLock.lock()
        cachedSnapshots = nil
        cachedSnapshotsByID = nil
        cacheLock.unlock()
    }
    #endif
}

/// Result of matching import dive metadata against the OpenDiveMap reference catalog.
struct DiveSiteReferenceMatch: Equatable, Sendable {
    let snapshot: DiveSiteReferenceSnapshot
    let score: Double
}

/// Fuzzy name + coordinate matching against OpenDiveMap reference rows and catalog tag lookup.
enum DiveSiteCatalogMatcher: Sendable {
    nonisolated static let openDiveMapTagPrefix = "opendivemap:"
    nonisolated static let autoLinkThreshold = 0.85
    nonisolated static let suggestThreshold = 0.70

    nonisolated static func openDiveMapSiteTag(referenceID: String) -> String {
        "\(openDiveMapTagPrefix)\(referenceID)"
    }

    nonisolated static func referenceID(from siteTags: [String]) -> String? {
        for tag in siteTags {
            guard tag.hasPrefix(openDiveMapTagPrefix) else { continue }
            let id = String(tag.dropFirst(openDiveMapTagPrefix.count))
            if !id.isEmpty { return id }
        }
        return nil
    }

    nonisolated static func normalizedSiteName(_ value: String) -> String {
        var text = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        while let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") {
            text.removeSubrange(open ... close)
        }
        text = text.replacingOccurrences(of: "[^a-z0-9 ]+", with: " ", options: .regularExpression)
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    nonisolated static func nameSimilarity(imported: String, reference: String) -> Double {
        let importedNormalized = normalizedSiteName(imported)
        let referenceNormalized = normalizedSiteName(reference)
        guard !importedNormalized.isEmpty, !referenceNormalized.isEmpty else { return 0 }
        if importedNormalized == referenceNormalized { return 1.0 }
        let minimumSubstringLength = 4
        if referenceNormalized.count >= minimumSubstringLength,
           importedNormalized.count >= minimumSubstringLength,
           (importedNormalized.contains(referenceNormalized) || referenceNormalized.contains(importedNormalized)) {
            return 0.85
        }

        let ratio = stringSimilarityRatio(importedNormalized, referenceNormalized)
        let importedTokens = sortedTokenKey(importedNormalized)
        let referenceTokens = sortedTokenKey(referenceNormalized)
        let tokenRatio = stringSimilarityRatio(importedTokens, referenceTokens)
        return max(ratio, tokenRatio)
    }

    nonisolated static func combinedMatchScore(
        importName: String?,
        importCoordinate: DiveCoordinate?,
        reference: DiveSiteReferenceSnapshot
    ) -> Double {
        let nameScore: Double
        if let importName, !importName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameScore = nameSimilarity(imported: importName, reference: reference.name)
        } else {
            nameScore = 0
        }

        let distanceMeters = coordinateDistanceMeters(
            importCoordinate: importCoordinate,
            referenceLatitude: reference.latitude,
            referenceLongitude: reference.longitude
        )

        if let importName,
           !importName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let importCoordinate,
           DiveMapCoordinateResolver.isUsable(importCoordinate),
           reference.latitude != nil,
           reference.longitude != nil {
            guard nameScore >= 0.6 else { return 0 }
            return nameScore * coordinateFactor(distanceMeters: distanceMeters)
        }

        if let importName,
           !importName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           importCoordinate == nil || !DiveMapCoordinateResolver.isUsable(importCoordinate) {
            return nameScore
        }

        if (importName == nil || importName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true),
           let importCoordinate,
           DiveMapCoordinateResolver.isUsable(importCoordinate),
           let distanceMeters {
            if distanceMeters <= 500 { return 0.95 }
            if distanceMeters <= 2_000 { return 0.85 }
            if distanceMeters <= 10_000 { return 0.7 }
            return 0
        }

        return 0
    }

    nonisolated static func bestReferenceMatch(
        importName: String?,
        importCoordinate: DiveCoordinate?,
        reference: [DiveSiteReferenceSnapshot],
        minimumScore: Double = autoLinkThreshold
    ) -> DiveSiteReferenceMatch? {
        guard !reference.isEmpty else { return nil }

        var best: DiveSiteReferenceMatch?
        for snapshot in reference {
            let score = combinedMatchScore(
                importName: importName,
                importCoordinate: importCoordinate,
                reference: snapshot
            )
            guard score >= minimumScore else { continue }
            if let current = best {
                if score > current.score {
                    best = DiveSiteReferenceMatch(snapshot: snapshot, score: score)
                } else if score == current.score,
                          snapshot.name.localizedCaseInsensitiveCompare(current.snapshot.name) == .orderedAscending {
                    best = DiveSiteReferenceMatch(snapshot: snapshot, score: score)
                }
            } else {
                best = DiveSiteReferenceMatch(snapshot: snapshot, score: score)
            }
        }
        return best
    }

    nonisolated static func catalogSite(
        forReferenceID referenceID: String,
        in catalogSites: [DiveSite]
    ) -> DiveSite? {
        let tag = openDiveMapSiteTag(referenceID: referenceID)
        return catalogSites.first { $0.siteTags.contains(tag) }
    }

    /// Trimmed catalog title — stored **`siteName`**, then bundled OpenDiveMap reference **`name`** when tagged.
    nonisolated static func resolvedCatalogSiteName(
        for site: DiveSite,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> String? {
        if let sanitized = DiveSiteFormValidation.sanitizedSiteName(site.siteName) {
            return sanitized
        }
        guard let referenceID = referenceID(from: site.siteTags) else { return nil }
        guard let snapshot = reference.first(where: { $0.id == referenceID }) else { return nil }
        return sanitizedReferenceDisplayName(snapshot.name)
    }

    /// Persists trimmed or reference-backed **`siteName`** when the stored value is blank or untrimmed.
    @discardableResult
    nonisolated static func normalizeCatalogSiteNameIfNeeded(
        _ site: DiveSite,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> Bool {
        if let sanitized = DiveSiteFormValidation.sanitizedSiteName(site.siteName) {
            guard sanitized != site.siteName else { return false }
            site.siteName = sanitized
            return true
        }
        guard let resolved = resolvedCatalogSiteName(for: site, reference: reference) else { return false }
        site.siteName = resolved
        return true
    }

    /// Maps known country aliases (e.g. **Dutch Caribbean**) to a canonical label.
    @discardableResult
    nonisolated static func normalizeCatalogSiteCountryIfNeeded(_ site: DiveSite) -> Bool {
        let canonical = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
        guard !canonical.isEmpty, canonical != site.country else { return false }
        site.country = canonical
        return true
    }

    nonisolated static func sanitizedReferenceDisplayName(_ raw: String) -> String? {
        DiveSiteFormValidation.sanitizedSiteName(raw)
    }

    nonisolated static func makeDiveSite(from reference: DiveSiteReferenceSnapshot) -> DiveSite {
        var tags = [openDiveMapSiteTag(referenceID: reference.id)]
        if !reference.entry.isEmpty { tags.append(reference.entry) }
        tags.append(contentsOf: reference.topologies)

        let siteName = sanitizedReferenceDisplayName(reference.name) ?? reference.id

        return DiveSite(
            siteName: siteName,
            country: DiveSiteCountryPresentation.canonicalDisplayName(for: reference.country),
            region: "",
            bodyOfWater: reference.seaName,
            latCoords: reference.latitude,
            longCoords: reference.longitude,
            siteTags: tags,
            entry: reference.entry,
            environment: reference.environment,
            maxDepthMeters: reference.maxDepthMeters,
            waterType: .saltwater
        )
    }

    @discardableResult
    nonisolated static func enrichCatalogSiteMetadataFromReferenceIfNeeded(
        _ site: DiveSite,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> Bool {
        guard let referenceID = referenceID(from: site.siteTags),
              let snapshot = reference.first(where: { $0.id == referenceID })
        else { return false }

        var changed = false
        if site.entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !snapshot.entry.isEmpty {
            site.entry = snapshot.entry
            changed = true
        }
        if site.environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !snapshot.environment.isEmpty {
            site.environment = snapshot.environment
            changed = true
        }
        if site.maxDepthMeters == nil, let maxDepthMeters = snapshot.maxDepthMeters {
            site.maxDepthMeters = maxDepthMeters
            changed = true
        }
        if site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !snapshot.seaName.isEmpty {
            site.bodyOfWater = snapshot.seaName
            changed = true
        }
        return changed
    }

    /// Adds an OpenDiveMap tag and reference metadata to a local-only catalog site when it strongly matches reference.
    @discardableResult
    nonisolated static func enrichCatalogSiteFromOpenDiveMapIfNeeded(
        _ site: DiveSite,
        catalogSites: [DiveSite],
        reference: [DiveSiteReferenceSnapshot],
        minimumScore: Double = autoLinkThreshold
    ) -> Bool {
        guard referenceID(from: site.siteTags) == nil else { return false }

        let coordinate = DiveMapCoordinateResolver.coordinate(from: site)
        guard let match = bestReferenceMatch(
            importName: site.siteName,
            importCoordinate: coordinate,
            reference: reference,
            minimumScore: minimumScore
        ) else { return false }
        guard catalogSite(forReferenceID: match.snapshot.id, in: catalogSites) == nil else { return false }

        let tag = openDiveMapSiteTag(referenceID: match.snapshot.id)
        if !site.siteTags.contains(tag) {
            site.siteTags.append(tag)
        }
        if site.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !match.snapshot.country.isEmpty {
            site.country = DiveSiteCountryPresentation.canonicalDisplayName(for: match.snapshot.country)
        }
        if site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !match.snapshot.seaName.isEmpty {
            site.bodyOfWater = match.snapshot.seaName
        }
        if site.entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !match.snapshot.entry.isEmpty {
            site.entry = match.snapshot.entry
        }
        if site.environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !match.snapshot.environment.isEmpty {
            site.environment = match.snapshot.environment
        }
        if site.maxDepthMeters == nil {
            site.maxDepthMeters = match.snapshot.maxDepthMeters
        }
        if site.latCoords == nil {
            site.latCoords = match.snapshot.latitude
        }
        if site.longCoords == nil {
            site.longCoords = match.snapshot.longitude
        }
        _ = normalizeCatalogSiteNameIfNeeded(site, reference: reference)
        return true
    }

    private nonisolated static func sortedTokenKey(_ normalizedName: String) -> String {
        normalizedName.split(whereSeparator: { $0.isWhitespace }).sorted().joined(separator: " ")
    }

    private nonisolated static func stringSimilarityRatio(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1.0 }
        let maxLength = max(lhs.count, rhs.count)
        guard maxLength > 0 else { return 0 }
        return 1.0 - Double(levenshteinDistance(lhs, rhs)) / Double(maxLength)
    }

    private nonisolated static func coordinateDistanceMeters(
        importCoordinate: DiveCoordinate?,
        referenceLatitude: Double?,
        referenceLongitude: Double?
    ) -> Double? {
        guard let importCoordinate,
              DiveMapCoordinateResolver.isUsable(importCoordinate),
              let referenceLatitude,
              let referenceLongitude else {
            return nil
        }
        return haversineDistanceMeters(
            lat1: importCoordinate.latitude,
            lon1: importCoordinate.longitude,
            lat2: referenceLatitude,
            lon2: referenceLongitude
        )
    }

    private nonisolated static func coordinateFactor(distanceMeters: Double?) -> Double {
        guard let distanceMeters else { return 1.0 }
        if distanceMeters <= 500 { return 1.0 }
        if distanceMeters <= 2_000 { return 0.95 }
        if distanceMeters <= 10_000 { return 0.85 }
        if distanceMeters <= 50_000 { return 0.7 }
        return 0.5
    }

    private nonisolated static func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let radiusM = 6_371_000.0
        let phi1 = lat1 * .pi / 180
        let phi2 = lat2 * .pi / 180
        let dPhi = (lat2 - lat1) * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let a = sin(dPhi / 2) * sin(dPhi / 2)
            + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * radiusM * atan2(sqrt(a), sqrt(1 - a))
    }

    private nonisolated static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0 ... right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for (leftIndex, leftCharacter) in left.enumerated() {
            current[0] = leftIndex + 1
            for (rightIndex, rightCharacter) in right.enumerated() {
                let insertionCost = previous[rightIndex + 1] + 1
                let deletionCost = current[rightIndex] + 1
                let substitutionCost = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                current[rightIndex + 1] = min(insertionCost, deletionCost, substitutionCost)
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}
