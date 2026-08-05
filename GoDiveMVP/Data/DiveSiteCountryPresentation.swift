import Foundation

/// One ISO country option for pickers (flag emoji + English label).
nonisolated struct DiveSiteSelectableCountry: Equatable, Hashable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let isoRegionCode: String
    let flagEmoji: String?

    var labeledDisplayName: String {
        if let flagEmoji, !flagEmoji.isEmpty {
            return "\(flagEmoji)  \(name)"
        }
        return name
    }
}

/// Canonical dive-site country labels and aliases (OpenDiveMap + catalog).
enum DiveSiteCountryPresentation: Sendable {
    nonisolated static let caribbeanNetherlands = "Caribbean Netherlands"

    private nonisolated static let canonicalByNormalizedAlias: [String: String] = [
        "dutch caribbean": caribbeanNetherlands,
        "caribbean netherlands": caribbeanNetherlands,
        "bonaire, sint eustatius and saba": caribbeanNetherlands,
        "bes islands": caribbeanNetherlands,
    ]

    /// Extra ISO options that must appear even when **`Locale`** naming is inconsistent.
    private nonisolated static let requiredSelectableCountries: [(code: String, name: String)] = [
        ("BQ", caribbeanNetherlands),
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

    /// ISO alpha-2 countries with flag emojis — same vocabulary as map / place-line flags.
    nonisolated static func selectableCountries(
        locale: Locale = Locale(identifier: "en_US")
    ) -> [DiveSiteSelectableCountry] {
        var byNormalizedName: [String: DiveSiteSelectableCountry] = [:]

        for region in Locale.Region.isoRegions {
            let code = region.identifier.uppercased()
            guard code.count == 2,
                  code.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) })
            else { continue }
            guard let rawName = locale.localizedString(forRegionCode: code) else { continue }
            let name = canonicalDisplayName(for: rawName)
            guard !name.isEmpty else { continue }
            let key = normalizedCountryKey(name)
            guard byNormalizedName[key] == nil else { continue }
            byNormalizedName[key] = DiveSiteSelectableCountry(
                name: name,
                isoRegionCode: code,
                flagEmoji: flagEmoji(forISORegionCode: code)
            )
        }

        for required in requiredSelectableCountries {
            let name = canonicalDisplayName(for: required.name)
            let key = normalizedCountryKey(name)
            if byNormalizedName[key] == nil {
                byNormalizedName[key] = DiveSiteSelectableCountry(
                    name: name,
                    isoRegionCode: required.code.uppercased(),
                    flagEmoji: flagEmoji(forISORegionCode: required.code)
                )
            }
        }

        return byNormalizedName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Keeps legacy free-text trip countries visible in the picker when they are not ISO options.
    nonisolated static func selectableCountries(
        includingSelected selected: [String],
        locale: Locale = Locale(identifier: "en_US")
    ) -> [DiveSiteSelectableCountry] {
        var options = selectableCountries(locale: locale)
        var seen = Set(options.map { normalizedCountryKey($0.name) })
        for raw in selected {
            let name = canonicalDisplayName(for: raw)
            guard !name.isEmpty else { continue }
            let key = normalizedCountryKey(name)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let code = isoRegionCode(forCountryName: name) ?? ""
            options.append(
                DiveSiteSelectableCountry(
                    name: name,
                    isoRegionCode: code,
                    flagEmoji: flagEmoji(forCountryName: name)
                )
            )
        }
        return options.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Extra picker search tokens that should not change stored catalog country labels.
    private nonisolated static let selectableSearchExtrasByCanonical: [String: [String]] = [
        caribbeanNetherlands: ["bonaire", "bes", "saba", "sint eustatius"],
    ]

    nonisolated static func matchesSelectableCountry(
        _ country: DiveSiteSelectableCountry,
        query: String
    ) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let needle = trimmed.lowercased()
        if country.name.lowercased().contains(needle) { return true }
        if country.isoRegionCode.lowercased().contains(needle) { return true }
        if searchTerms(for: country.name).contains(where: { $0.lowercased().contains(needle) }) {
            return true
        }
        let extras = selectableSearchExtrasByCanonical[country.name] ?? []
        return extras.contains { extra in
            extra.contains(needle) || needle.contains(extra)
        }
    }
}
