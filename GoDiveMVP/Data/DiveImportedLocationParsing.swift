import Foundation

/// Splits dive import **`locationName`** (often `"region, country"`) into catalog place fields.
enum DiveImportedLocationParsing {
    struct PlaceFields: Equatable, Sendable {
        var region: String
        var country: String
    }

    /// Text before the first comma → **region**; text after → **country**. With no comma, the whole string is **region**.
    nonisolated static func placeFields(fromLocationName locationName: String?) -> PlaceFields {
        guard let trimmed = trimmedNonEmpty(locationName) else {
            return PlaceFields(region: "", country: "")
        }
        guard let commaIndex = trimmed.firstIndex(of: ",") else {
            return PlaceFields(region: trimmed, country: "")
        }
        let region = String(trimmed[..<commaIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let country = String(trimmed[trimmed.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PlaceFields(region: region, country: country)
    }

    private nonisolated static func trimmedNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
