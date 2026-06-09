import Foundation

/// Lightweight catalog row for Fishial scientific-name matching (testable without SwiftData).
struct FishialMarineLifeCatalogSnapshot: Equatable, Sendable {
    let uuid: String
    let scientificName: String
    let commonName: String
    let featureImageURL: String

    init(
        uuid: String,
        scientificName: String,
        commonName: String,
        featureImageURL: String
    ) {
        self.uuid = uuid
        self.scientificName = scientificName
        self.commonName = commonName
        self.featureImageURL = featureImageURL
    }

    init(marineLife: MarineLife) {
        uuid = marineLife.uuid
        scientificName = marineLife.scientificName
        commonName = marineLife.commonName
        featureImageURL = marineLife.featureImageURL
    }
}

/// One Fishial candidate mapped onto a Field Guide catalog species for review UI.
struct FishialCatalogReviewOption: Sendable {
    let marineLifeUUID: String
    let catalogCommonName: String
    let catalogScientificName: String
    let featureImageURL: String
    let fishialScientificName: String
    let fishialAccuracy: Double
    let nameMatchScore: Double

    nonisolated var combinedScore: Double {
        fishialAccuracy * nameMatchScore
    }
}

extension FishialCatalogReviewOption: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.marineLifeUUID == rhs.marineLifeUUID
            && lhs.catalogCommonName == rhs.catalogCommonName
            && lhs.catalogScientificName == rhs.catalogScientificName
            && lhs.featureImageURL == rhs.featureImageURL
            && lhs.fishialScientificName == rhs.fishialScientificName
            && lhs.fishialAccuracy == rhs.fishialAccuracy
            && lhs.nameMatchScore == rhs.nameMatchScore
    }
}

/// Fuzzy-matches Fishial scientific names onto bundled Field Guide catalog rows.
enum FishialMarineLifeCatalogMatching: Sendable {

    nonisolated static let defaultMinimumSimilarity = 0.72
    nonisolated static let defaultMaximumOptions = 5

    nonisolated static func normalizedScientificName(_ value: String) -> String {
        value.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .joined(separator: " ")
    }

    nonisolated static func scientificNameSimilarity(fishial: String, catalog: String) -> Double {
        let fishialNormalized = normalizedScientificName(fishial)
        let catalogNormalized = normalizedScientificName(catalog)
        guard !fishialNormalized.isEmpty, !catalogNormalized.isEmpty else { return 0 }
        if fishialNormalized == catalogNormalized { return 1.0 }

        let fishialTokens = fishialNormalized.split(separator: " ").map(String.init)
        let catalogTokens = catalogNormalized.split(separator: " ").map(String.init)

        if fishialTokens.count >= 2, catalogTokens.count >= 2 {
            if fishialTokens[0] == catalogTokens[0], fishialTokens[1] == catalogTokens[1] {
                return 0.98
            }
            if fishialTokens[0] == catalogTokens[0] {
                let speciesSimilarity = tokenSimilarity(fishialTokens[1], catalogTokens[1])
                return 0.5 + 0.48 * speciesSimilarity
            }
        }

        if fishialNormalized.contains(catalogNormalized) || catalogNormalized.contains(fishialNormalized) {
            return 0.85
        }

        let jaccard = tokenJaccard(fishialTokens, catalogTokens)
        let maxLength = max(fishialNormalized.count, catalogNormalized.count)
        let levenshteinRatio = maxLength > 0
            ? 1.0 - Double(levenshteinDistance(fishialNormalized, catalogNormalized)) / Double(maxLength)
            : 0
        return max(jaccard, levenshteinRatio)
    }

    nonisolated static func catalogReviewOptions(
        from rankedSpecies: [FishialRankedSpecies],
        catalog: [FishialMarineLifeCatalogSnapshot],
        minimumSimilarity: Double = defaultMinimumSimilarity,
        maximumOptions: Int = defaultMaximumOptions
    ) -> [FishialCatalogReviewOption] {
        guard !rankedSpecies.isEmpty, !catalog.isEmpty else { return [] }

        var options: [FishialCatalogReviewOption] = []
        for ranked in rankedSpecies {
            guard let match = bestCatalogMatch(
                for: ranked.scientificName,
                catalog: catalog,
                minimumSimilarity: minimumSimilarity
            ) else { continue }
            options.append(
                FishialCatalogReviewOption(
                    marineLifeUUID: match.snapshot.uuid,
                    catalogCommonName: match.snapshot.commonName,
                    catalogScientificName: match.snapshot.scientificName,
                    featureImageURL: match.snapshot.featureImageURL,
                    fishialScientificName: ranked.scientificName,
                    fishialAccuracy: ranked.accuracy,
                    nameMatchScore: match.similarity
                )
            )
        }

        var bestByUUID: [String: FishialCatalogReviewOption] = [:]
        for option in options {
            if let existing = bestByUUID[option.marineLifeUUID] {
                if option.combinedScore > existing.combinedScore {
                    bestByUUID[option.marineLifeUUID] = option
                }
            } else {
                bestByUUID[option.marineLifeUUID] = option
            }
        }

        return bestByUUID.values
            .sorted { lhs, rhs in
                if lhs.combinedScore != rhs.combinedScore { return lhs.combinedScore > rhs.combinedScore }
                return lhs.catalogCommonName.localizedCaseInsensitiveCompare(rhs.catalogCommonName)
                    == .orderedAscending
            }
            .prefix(maximumOptions)
            .map { $0 }
    }

    private struct CatalogMatchCandidate: Equatable, Sendable {
        let snapshot: FishialMarineLifeCatalogSnapshot
        let similarity: Double
    }

    nonisolated private static func bestCatalogMatch(
        for fishialScientificName: String,
        catalog: [FishialMarineLifeCatalogSnapshot],
        minimumSimilarity: Double
    ) -> CatalogMatchCandidate? {
        var best: CatalogMatchCandidate?
        for entry in catalog {
            let similarity = scientificNameSimilarity(
                fishial: fishialScientificName,
                catalog: entry.scientificName
            )
            guard similarity >= minimumSimilarity else { continue }
            if let current = best {
                if similarity > current.similarity {
                    best = CatalogMatchCandidate(snapshot: entry, similarity: similarity)
                } else if similarity == current.similarity,
                          entry.commonName.localizedCaseInsensitiveCompare(current.snapshot.commonName)
                            == .orderedAscending {
                    best = CatalogMatchCandidate(snapshot: entry, similarity: similarity)
                }
            } else {
                best = CatalogMatchCandidate(snapshot: entry, similarity: similarity)
            }
        }
        return best
    }

    nonisolated private static func tokenJaccard(_ lhs: [String], _ rhs: [String]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let intersection = left.intersection(right).count
        let union = left.union(right).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    nonisolated private static func tokenSimilarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1.0 }
        let maxLength = max(lhs.count, rhs.count)
        guard maxLength > 0 else { return 0 }
        return 1.0 - Double(levenshteinDistance(lhs, rhs)) / Double(maxLength)
    }

    nonisolated private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
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
