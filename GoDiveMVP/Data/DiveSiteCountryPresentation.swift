import Foundation

/// Canonical dive-site country labels and aliases (OpenDiveMap + catalog).
enum DiveSiteCountryPresentation: Sendable {
    nonisolated static let caribbeanNetherlands = "Caribbean Netherlands"

    private nonisolated static let canonicalByNormalizedAlias: [String: String] = [
        "dutch caribbean": caribbeanNetherlands,
        "caribbean netherlands": caribbeanNetherlands,
        "bonaire, sint eustatius and saba": caribbeanNetherlands,
        "bes islands": caribbeanNetherlands,
    ]

    /// Preferred stored / section title for a country string.
    nonisolated static func canonicalDisplayName(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let canonical = canonicalByNormalizedAlias[normalizedCountryKey(trimmed)] {
            return canonical
        }
        return trimmed
    }

    /// Raw label plus canonical name and known aliases (for Explore search haystacks).
    nonisolated static func searchTerms(for raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let canonical = canonicalDisplayName(for: trimmed)
        var terms = [trimmed, canonical]
        for (alias, target) in canonicalByNormalizedAlias where target == canonical {
            terms.append(alias)
        }

        var seen = Set<String>()
        return terms.filter { term in
            let key = normalizedCountryKey(term)
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private nonisolated static func normalizedCountryKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
