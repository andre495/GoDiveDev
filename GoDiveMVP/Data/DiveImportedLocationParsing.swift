import Foundation

/// Splits dive import **`locationName`** (often `"city, state, country"` from UDDF) into catalog place fields.
enum DiveImportedLocationParsing {
    struct PlaceFields: Equatable, Sendable {
        var region: String
        var country: String
    }

    /// Picks a trailing segment that matches a known country (ISO / catalog aliases); remaining segments → **region**.
    /// Falls back to a single comma split when no country is recognized.
    nonisolated static func placeFields(fromLocationName locationName: String?) -> PlaceFields {
        guard let trimmed = trimmedNonEmpty(locationName) else {
            return PlaceFields(region: "", country: "")
        }
        let parts = commaSeparatedParts(trimmed)

        if parts.count <= 1 {
            let only = parts.first ?? trimmed
            if isRecognizedCountry(only) {
                return PlaceFields(region: "", country: canonicalCountry(only))
            }
            return PlaceFields(region: only, country: "")
        }

        let maxCountryParts = min(4, parts.count)
        for partCount in stride(from: maxCountryParts, through: 1, by: -1) {
            let startIndex = parts.count - partCount
            let candidate = parts[startIndex...].joined(separator: ", ")
            if isRecognizedCountry(candidate) {
                let region = parts[..<startIndex].joined(separator: ", ")
                return PlaceFields(region: region, country: canonicalCountry(candidate))
            }
        }

        return placeFieldsFirstCommaFallback(trimmed)
    }

    private nonisolated static func placeFieldsFirstCommaFallback(_ trimmed: String) -> PlaceFields {
        guard let commaIndex = trimmed.firstIndex(of: ",") else {
            return PlaceFields(region: trimmed, country: "")
        }
        let region = String(trimmed[..<commaIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let country = String(trimmed[trimmed.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PlaceFields(region: region, country: country)
    }

    private nonisolated static func commaSeparatedParts(_ trimmed: String) -> [String] {
        trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private nonisolated static func isRecognizedCountry(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return DiveSiteCountryPresentation.isoRegionCode(forCountryName: trimmed) != nil
    }

    private nonisolated static func canonicalCountry(_ raw: String) -> String {
        DiveSiteCountryPresentation.canonicalDisplayName(for: raw)
    }

    private nonisolated static func trimmedNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
