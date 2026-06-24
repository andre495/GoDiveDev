import Foundation

/// Explore list row alias — unified **`DiveSiteDisplayRecord`** for catalog + OpenDiveMap.
typealias ExploreDiveSiteRowDisplayData = DiveSiteDisplayRecord

enum ExploreDiveSiteRowTrailingStyle: Equatable, Sendable {
    /// Explore catalog — dive count on the trailing edge when **> 0**.
    case catalogDefault
    /// Planned trip saved sites — omit dive counts.
    case plannedTrip

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.catalogDefault, .catalogDefault), (.plannedTrip, .plannedTrip):
            return true
        default:
            return false
        }
    }
}

/// Builds Explore dive-site list rows sorted by **`siteName`** (caller supplies sorted sites).
enum ExploreDiveSiteListDisplay {
    nonisolated static func rowData(
        for sites: [DiveSite],
        trailingStyle: ExploreDiveSiteRowTrailingStyle = .catalogDefault
    ) -> [ExploreDiveSiteRowDisplayData] {
        DiveSitePresentation.listRecords(for: sites, trailingStyle: trailingStyle)
    }

    /// Place hierarchy for search (safe from **`nonisolated`** callers).
    nonisolated static func placeSummary(
        country: String,
        region: String,
        bodyOfWater: String
    ) -> String {
        let country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines)
        return [country, region, body].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func placeSummary(for site: DiveSite) -> String {
        placeSummary(country: site.country, region: site.region, bodyOfWater: site.bodyOfWater)
    }

    /// Locality + country for legacy call sites — prefer **`DiveSitePresentation.listPlaceLine`**.
    nonisolated static func cityCountryLine(country: String, region: String) -> String {
        DiveSitePresentation.listPlaceLine(country: country, region: region, bodyOfWater: "")
    }
}
