import Foundation

/// Pipe-delimited scientific names persisted on **`DiveMediaPhoto.fishialConfirmedSpeciesName`**.
enum FishialConfirmedSpeciesPresentation: Sendable {
    nonisolated static let storageDelimiter = "|"

    nonisolated static func parsedScientificNames(from storedValue: String) -> [String] {
        storedValue
            .split(separator: Character(storageDelimiter))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    nonisolated static func storageValue(for scientificNames: [String]) -> String {
        scientificNames.joined(separator: storageDelimiter)
    }

    nonisolated static func mergedScientificNames(
        existingStoredValue: String,
        adding newNames: [String]
    ) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []

        func append(_ name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            merged.append(trimmed)
        }

        for name in parsedScientificNames(from: existingStoredValue) {
            append(name)
        }
        for name in newNames {
            append(name)
        }
        return merged
    }

    nonisolated static func savedFishIDNote(speciesCount: Int) -> String {
        switch speciesCount {
        case 0:
            return ""
        case 1:
            return "This species is tagged on the photo. A sparkles badge on the species chip marks Fishial AI identification."
        default:
            return "These species are tagged on the photo. A sparkles badge on each species chip marks Fishial AI identification."
        }
    }
}
