import Foundation

/// On-device biology similarity for Field Guide species (port of ontology `similarity.py` biology path).
///
/// Hard facets build the candidate set; soft color / size / category / depth scores apply only to
/// candidates already matched. No RDF runtime; scores are not persisted on catalog rows.
nonisolated enum MarineLifeBiologySimilarity: Sendable {

    static let defaultLimit = 6

    enum Weights {
        static let familyName = 4.0
        static let subcategory = 3.0
        static let bodyShape = 2.5
        static let colorOverlap = 2.5
        static let sizeOverlap = 2.5
        static let sizeSimilar = 2.0
        static let category = 1.5
        static let depthOverlap = 1.0
    }

    struct Evidence: Sendable, Equatable, Hashable {
        let signal: String
        let weight: Double
        let detail: String?
    }

    struct RankedMatch: Sendable, Equatable, Identifiable, Hashable {
        var id: String { uuid }
        let uuid: String
        let score: Double
        let evidence: [Evidence]
    }

    struct CombinedRankedMatch: Sendable, Equatable, Identifiable, Hashable {
        var id: String { uuid }
        let uuid: String
        let totalScore: Double
        let biologyScore: Double
        let sightingScore: Double
    }

    /// Merges on-device biology ranks with CDN community sighting scores.
    nonisolated static func merge(
        biology: [RankedMatch],
        sightingScoresByUUID: [String: Double],
        limit: Int = defaultLimit
    ) -> [CombinedRankedMatch] {
        var totals: [String: (bio: Double, sight: Double)] = [:]
        for row in biology {
            totals[row.uuid] = (row.score, sightingScoresByUUID[row.uuid] ?? 0)
        }
        for (uuid, sight) in sightingScoresByUUID where sight > 0 {
            if totals[uuid] == nil {
                totals[uuid] = (0, sight)
            } else if let existing = totals[uuid], existing.sight == 0 {
                totals[uuid] = (existing.bio, sight)
            }
        }
        let ranked = totals.map { uuid, scores in
            CombinedRankedMatch(
                uuid: uuid,
                totalScore: ((scores.bio + scores.sight) * 100).rounded() / 100,
                biologyScore: scores.bio,
                sightingScore: scores.sight
            )
        }
        .filter { $0.totalScore > 0 }
        .sorted {
            if $0.totalScore != $1.totalScore { return $0.totalScore > $1.totalScore }
            return $0.uuid < $1.uuid
        }
        let capped = max(0, min(limit, 50))
        return Array(ranked.prefix(capped))
    }

    /// Ranks catalog species by biology similarity to `seed`. Caps at `limit` (default 6).
    nonisolated static func rank(
        seed: MarineLifeCatalogSnapshot,
        catalog: [MarineLifeCatalogSnapshot],
        limit: Int = defaultLimit
    ) -> [RankedMatch] {
        let seedUUID = seed.uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !seedUUID.isEmpty else { return [] }

        var entries: [String: MutableEntry] = [:]

        let seedFamily = normalizedToken(seed.familyName)
        if !seedFamily.isEmpty {
            for candidate in catalog where candidate.uuid != seedUUID {
                guard normalizedToken(candidate.familyName) == seedFamily else { continue }
                addSignal(
                    &entries,
                    uuid: candidate.uuid,
                    signal: "familyName",
                    weight: Weights.familyName,
                    detail: seed.familyName
                )
            }
        }

        let seedSubcategory = normalizedToken(seed.subcategory)
        if !seedSubcategory.isEmpty {
            for candidate in catalog where candidate.uuid != seedUUID {
                guard normalizedToken(candidate.subcategory) == seedSubcategory else { continue }
                addSignal(
                    &entries,
                    uuid: candidate.uuid,
                    signal: "subcategory",
                    weight: Weights.subcategory,
                    detail: seed.subcategory
                )
            }
        }

        if let seedShape = bodyShape(from: seed.distinctiveFeatures) {
            let seedShapeKey = seedShape.lowercased()
            for candidate in catalog where candidate.uuid != seedUUID {
                guard let candShape = bodyShape(from: candidate.distinctiveFeatures),
                      candShape.lowercased() == seedShapeKey
                else { continue }
                addSignal(
                    &entries,
                    uuid: candidate.uuid,
                    signal: "bodyShape",
                    weight: Weights.bodyShape,
                    detail: seedShape
                )
            }
        }

        let seedCategory = normalizedToken(seed.category)
        let seedColors = colorTerms(from: seed.aboutText)
        let seedMinSize = optionalPositive(seed.minSizeMeters)
        let seedMaxSize = optionalPositive(seed.maxSizeMeters)
        let seedMinDepth = optionalPositive(seed.minDepthMeters)
        let seedMaxDepth = optionalPositive(seed.maxDepthMeters)
        let hasFullSeedSize = seedMinSize != nil && seedMaxSize != nil

        let catalogByUUID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })

        for uuid in Array(entries.keys) {
            guard let candidate = catalogByUUID[uuid] else { continue }
            var entry = entries[uuid]!

            let candCategory = normalizedToken(candidate.category)
            if !seedCategory.isEmpty, seedCategory == candCategory {
                addSignal(
                    to: &entry,
                    signal: "category",
                    weight: Weights.category,
                    detail: candidate.category
                )
            }

            let sharedColors = seedColors.intersection(colorTerms(from: candidate.aboutText)).sorted()
            if !sharedColors.isEmpty, entry.signals["colorOverlap"] == nil {
                addSignal(
                    to: &entry,
                    signal: "colorOverlap",
                    weight: Weights.colorOverlap,
                    detail: sharedColors.joined(separator: ",")
                )
            }

            let candMinSize = optionalPositive(candidate.minSizeMeters)
            let candMaxSize = optionalPositive(candidate.maxSizeMeters)
            let hasFullCandSize = candMinSize != nil && candMaxSize != nil
            if hasFullSeedSize, hasFullCandSize,
               rangesOverlap(seedMinSize, seedMaxSize, candMinSize, candMaxSize) {
                addSignal(
                    to: &entry,
                    signal: "sizeOverlap",
                    weight: Weights.sizeOverlap,
                    detail: sizeRangeDetail(min: candMinSize, max: candMaxSize)
                )
            } else if maxSizeSimilar(seedMaxSize, candMaxSize) {
                addSignal(
                    to: &entry,
                    signal: "sizeSimilar",
                    weight: Weights.sizeSimilar,
                    detail: candMaxSize.map { String(format: "max~%.3gm", $0) }
                )
            }

            let candMinDepth = optionalPositive(candidate.minDepthMeters)
            let candMaxDepth = optionalPositive(candidate.maxDepthMeters)
            if let seedMinDepth, let seedMaxDepth, let candMinDepth, let candMaxDepth,
               seedMinDepth <= candMaxDepth, candMinDepth <= seedMaxDepth {
                addSignal(
                    to: &entry,
                    signal: "depthOverlap",
                    weight: Weights.depthOverlap,
                    detail: sizeRangeDetail(min: candMinDepth, max: candMaxDepth)
                )
            }

            entries[uuid] = entry
        }

        let nameByUUID = Dictionary(
            uniqueKeysWithValues: catalog.map {
                ($0.uuid, $0.commonName.lowercased())
            }
        )

        let ranked = entries.values
            .filter { $0.score > 0 }
            .map { entry in
                RankedMatch(
                    uuid: entry.uuid,
                    score: (entry.score * 100).rounded() / 100,
                    evidence: entry.evidence.sorted {
                        if $0.weight != $1.weight { return $0.weight > $1.weight }
                        return $0.signal < $1.signal
                    }
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let leftName = nameByUUID[lhs.uuid] ?? lhs.uuid
                let rightName = nameByUUID[rhs.uuid] ?? rhs.uuid
                return leftName < rightName
            }

        let capped = max(0, min(limit, 50))
        return Array(ranked.prefix(capped))
    }

    // MARK: - Internals

    private struct MutableEntry {
        var uuid: String
        var score: Double = 0
        var signals: [String: Evidence] = [:]
        var evidence: [Evidence] = []
    }

    private nonisolated static func addSignal(
        _ entries: inout [String: MutableEntry],
        uuid: String,
        signal: String,
        weight: Double,
        detail: String?
    ) {
        var entry = entries[uuid] ?? MutableEntry(uuid: uuid)
        addSignal(to: &entry, signal: signal, weight: weight, detail: detail)
        entries[uuid] = entry
    }

    private nonisolated static func addSignal(
        to entry: inout MutableEntry,
        signal: String,
        weight: Double,
        detail: String?
    ) {
        guard entry.signals[signal] == nil else { return }
        let evidence = Evidence(signal: signal, weight: weight, detail: detail)
        entry.signals[signal] = evidence
        entry.score += weight
        entry.evidence.append(evidence)
    }

    nonisolated static func bodyShape(from distinctiveFeatures: String) -> String? {
        for line in distinctiveFeatures.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.lowercased().hasPrefix("body shape") {
                return trimmed
            }
        }
        let trimmed = distinctiveFeatures.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased().hasPrefix("body shape") ? trimmed : nil
    }

    nonisolated static func colorTerms(from text: String) -> Set<String> {
        guard !text.isEmpty else { return [] }
        var found: Set<String> = []
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        colorRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            var token = ns.substring(with: match.range(at: 1)).lowercased()
            if token == "grey" { token = "gray" }
            found.insert(token)
        }
        return found
    }

    private nonisolated static func normalizedToken(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private nonisolated static func optionalPositive(_ value: Double) -> Double? {
        value > 0 ? value : nil
    }

    private nonisolated static func rangesOverlap(
        _ a0: Double?,
        _ a1: Double?,
        _ b0: Double?,
        _ b1: Double?
    ) -> Bool {
        guard let a0, let a1, let b0, let b1 else { return false }
        return a0 <= b1 && b0 <= a1
    }

    private nonisolated static func maxSizeSimilar(
        _ a: Double?,
        _ b: Double?,
        tolerance: Double = 0.35
    ) -> Bool {
        guard let a, let b, a > 0, b > 0 else { return false }
        return max(a, b) / min(a, b) <= 1.0 + tolerance
    }

    private nonisolated static func sizeRangeDetail(min: Double?, max: Double?) -> String? {
        guard let min, let max else { return nil }
        return String(format: "%.3g-%.3gm", min, max)
    }

    private static let colorTermsList = [
        "black", "white", "gray", "grey", "yellow", "blue", "red", "orange", "green",
        "brown", "purple", "pink", "silver", "gold", "tan", "cream", "violet", "olive",
        "turquoise", "cyan", "scarlet", "maroon",
    ]

    private static let colorRegex: NSRegularExpression = {
        let alternation = colorTermsList.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // Pattern is built from a fixed literal list.
        return try! NSRegularExpression(pattern: "\\b(\(alternation))\\b", options: [.caseInsensitive])
    }()
}
