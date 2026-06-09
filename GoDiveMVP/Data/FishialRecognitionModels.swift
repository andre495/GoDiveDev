import Foundation

/// One species candidate returned by Fishial recognition (flattened for UI).
struct FishialSpeciesMatch: Equatable, Sendable {
    let name: String
    let accuracy: Double
}

/// One detected fish shape on an image.
struct FishialDetectedFish: Equatable, Sendable, Decodable {
    let species: [FishialSpeciesCandidate]

    private enum CodingKeys: String, CodingKey {
        case species
    }

    init(species: [FishialSpeciesCandidate]) {
        self.species = species
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        species = try container.decodeIfPresent([FishialSpeciesCandidate].self, forKey: .species) ?? []
    }
}

/// Species candidate on a detected fish object (**`/v2/recognize`**).
struct FishialSpeciesCandidate: Equatable, Sendable, Decodable {
    let id: String
    let certainty: Double

    private enum CodingKeys: String, CodingKey {
        case id
        case certainty
    }

    init(id: String, certainty: Double) {
        self.id = id
        self.certainty = certainty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let value = try? container.decode(Double.self, forKey: .certainty) {
            certainty = value
        } else if let intValue = try? container.decode(Int.self, forKey: .certainty) {
            certainty = Double(intValue)
        } else {
            certainty = 0
        }
    }
}

/// Species metadata keyed by UUID in **`/v2/recognize`** responses.
struct FishialSpeciesDefinition: Equatable, Sendable, Decodable {
    let commonName: String?
    let scientificName: String?
    let imageURL: String?

    private enum CodingKeys: String, CodingKey {
        case commonName
        case scientificName
        case imageURL = "imageUrl"
    }
}

/// Full Fishial **`/v2/recognize`** payload.
struct FishialRecognitionResponse: Equatable, Sendable, Decodable {
    let ok: Bool
    let queryToken: String?
    let objects: [FishialDetectedFish]
    let definitions: [String: FishialSpeciesDefinition]
    let error: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case queryToken
        case objects
        case definitions
        case error
        case message
    }

    init(
        ok: Bool,
        queryToken: String? = nil,
        objects: [FishialDetectedFish] = [],
        definitions: [String: FishialSpeciesDefinition] = [:],
        error: String? = nil,
        message: String? = nil
    ) {
        self.ok = ok
        self.queryToken = queryToken
        self.objects = objects
        self.definitions = definitions
        self.error = error
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        queryToken = try container.decodeIfPresent(String.self, forKey: .queryToken)
        objects = try container.decodeIfPresent([FishialDetectedFish].self, forKey: .objects) ?? []
        definitions = try container.decodeIfPresent([String: FishialSpeciesDefinition].self, forKey: .definitions) ?? [:]
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

/// De-duplicated Fishial species candidate — top-level so properties stay **nonisolated** (Swift 6).
struct FishialRankedSpecies: Sendable {
    let scientificName: String
    let accuracy: Double
}

extension FishialRankedSpecies: Equatable {
    /// Explicit **nonisolated** equality for Swift Testing **`#expect`** (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.scientificName == rhs.scientificName && lhs.accuracy == rhs.accuracy
    }
}

/// Flattened, de-duplicated species candidates sorted by best accuracy (descending).
enum FishialRecognitionPresentation: Sendable {

    typealias RankedSpecies = FishialRankedSpecies

    nonisolated static func displayName(
        for candidate: FishialSpeciesCandidate,
        definitions: [String: FishialSpeciesDefinition]
    ) -> String {
        let definition = definitions[candidate.id]
        let scientific = definition?.scientificName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !scientific.isEmpty { return scientific }
        let common = definition?.commonName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !common.isEmpty { return common }
        return candidate.id
    }

    nonisolated static func rankedSpecies(
        from response: FishialRecognitionResponse
    ) -> [RankedSpecies] {
        var bestAccuracyByName: [String: Double] = [:]
        for fish in response.objects {
            for candidate in fish.species {
                let name = displayName(for: candidate, definitions: response.definitions)
                guard !name.isEmpty else { continue }
                let prior = bestAccuracyByName[name] ?? -.infinity
                bestAccuracyByName[name] = max(prior, candidate.certainty)
            }
        }
        return bestAccuracyByName
            .map { RankedSpecies(scientificName: $0.key, accuracy: $0.value) }
            .sorted {
                if $0.accuracy != $1.accuracy { return $0.accuracy > $1.accuracy }
                return $0.scientificName.localizedCaseInsensitiveCompare($1.scientificName) == .orderedAscending
            }
    }

    nonisolated static func speciesMatches(
        from response: FishialRecognitionResponse
    ) -> [FishialSpeciesMatch] {
        response.objects.flatMap { fish in
            fish.species.map { candidate in
                FishialSpeciesMatch(
                    name: displayName(for: candidate, definitions: response.definitions),
                    accuracy: candidate.certainty
                )
            }
        }
    }

    nonisolated static func rankedSpecies(
        merging responses: [FishialRecognitionResponse]
    ) -> [RankedSpecies] {
        var bestAccuracyByName: [String: Double] = [:]
        for response in responses {
            for ranked in rankedSpecies(from: response) {
                let prior = bestAccuracyByName[ranked.scientificName] ?? -.infinity
                bestAccuracyByName[ranked.scientificName] = max(prior, ranked.accuracy)
            }
        }
        return bestAccuracyByName
            .map { RankedSpecies(scientificName: $0.key, accuracy: $0.value) }
            .sorted {
                if $0.accuracy != $1.accuracy { return $0.accuracy > $1.accuracy }
                return $0.scientificName.localizedCaseInsensitiveCompare($1.scientificName) == .orderedAscending
            }
    }
}
