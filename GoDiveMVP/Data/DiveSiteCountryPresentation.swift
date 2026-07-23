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

    /// ISO 3166-1 alpha-2 overrides when **`Locale`** English names do not match catalog labels.
    private nonisolated static let isoRegionCodeByNormalizedName: [String: String] = [
        "caribbean netherlands": "BQ",
        "united states": "US",
        "united states of america": "US",
        "usa": "US",
        "u.s.": "US",
        "u.s.a.": "US",
        "united kingdom": "GB",
        "uk": "GB",
        "great britain": "GB",
    ]

    /// Regional indicator flag emoji for a country label (e.g. **United States** → 🇺🇸); **`nil`** when unknown.
    nonisolated static func flagEmoji(forCountryName raw: String) -> String? {
        guard let code = isoRegionCode(forCountryName: raw) else { return nil }
        return flagEmoji(forISORegionCode: code)
    }

    nonisolated static func isoRegionCode(forCountryName raw: String) -> String? {
        let canonical = canonicalDisplayName(for: raw)
        guard !canonical.isEmpty else { return nil }
        let key = normalizedCountryKey(canonical)
        if let code = isoRegionCodeByNormalizedName[key] {
            return code
        }
        let locale = Locale(identifier: "en_US")
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard let name = locale.localizedString(forRegionCode: code) else { continue }
            if normalizedCountryKey(name) == key {
                return code
            }
        }
        return nil
    }

    nonisolated static func flagEmoji(forISORegionCode code: String) -> String? {
        let upper = code.uppercased()
        guard upper.count == 2,
              upper.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) })
        else { return nil }

        var scalars = String.UnicodeScalarView()
        let base: UInt32 = 127_397
        for scalar in upper.unicodeScalars {
            guard let regional = UnicodeScalar(base + scalar.value) else { return nil }
            scalars.append(regional)
        }
        return String(scalars)
    }

    /// Prefixes a location line with the country flag when mapping succeeds (e.g. 🇺🇸 Midway, Utah, United States).
    nonisolated static func prefixedWithFlagEmoji(_ line: String, countryName raw: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }
        guard let flag = flagEmoji(forCountryName: raw), !flag.isEmpty else { return line }
        return "\(flag) \(trimmed)"
    }
}
