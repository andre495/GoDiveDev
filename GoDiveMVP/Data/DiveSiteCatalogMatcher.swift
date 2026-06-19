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

    private nonisolated(unsafe) static var cachedSnapshots: [DiveSiteReferenceSnapshot]?

    nonisolated static func bundledReference(
        bundle: Bundle = .main,
        resourceExtension: String = "json"
    ) -> [DiveSiteReferenceSnapshot] {
        if let cachedSnapshots {
            return cachedSnapshots
        }
        guard let fileURL = bundle.url(
            forResource: bundledResourceName,
            withExtension: resourceExtension
        ) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([DiveSiteReferenceSnapshot].self, from: data)
            cachedSnapshots = decoded
            return decoded
        } catch {
            return []
        }
    }

    #if DEBUG
    nonisolated static func resetCacheForTesting() {
        cachedSnapshots = nil
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

    nonisolated static func makeDiveSite(from reference: DiveSiteReferenceSnapshot) -> DiveSite {
        var tags = [openDiveMapSiteTag(referenceID: reference.id)]
        if !reference.entry.isEmpty { tags.append(reference.entry) }
        tags.append(contentsOf: reference.topologies)

        return DiveSite(
            siteName: reference.name,
            country: reference.country,
            region: "",
            bodyOfWater: reference.seaName,
            latCoords: reference.latitude,
            longCoords: reference.longitude,
            siteTags: tags,
            waterType: .saltwater
        )
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
            site.country = match.snapshot.country
        }
        if site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !match.snapshot.seaName.isEmpty {
            site.bodyOfWater = match.snapshot.seaName
        }
        if site.latCoords == nil {
            site.latCoords = match.snapshot.latitude
        }
        if site.longCoords == nil {
            site.longCoords = match.snapshot.longitude
        }
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
