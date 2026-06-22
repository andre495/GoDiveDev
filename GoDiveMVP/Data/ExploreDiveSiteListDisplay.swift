import Foundation

/// Stable, **`Equatable`** Explore list row payload (logbook-style rows).
struct ExploreDiveSiteRowDisplayData: Equatable, Identifiable, Sendable {
    let id: UUID
    /// OpenDiveMap reference id when the row represents a bundled reference site.
    let referenceID: String?
    let displayName: String
    /// Trailing dive count (catalog list only) — e.g. **"12 dives"**.
    let diveCountLabel: String?
    let coordinateLine: String
    let placeLine: String?

    nonisolated init(
        id: UUID,
        referenceID: String? = nil,
        displayName: String,
        diveCountLabel: String?,
        coordinateLine: String,
        placeLine: String?
    ) {
        self.id = id
        self.referenceID = referenceID
        self.displayName = displayName
        self.diveCountLabel = diveCountLabel
        self.coordinateLine = coordinateLine
        self.placeLine = placeLine
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.referenceID == rhs.referenceID
            && lhs.displayName == rhs.displayName
            && lhs.diveCountLabel == rhs.diveCountLabel
            && lhs.coordinateLine == rhs.coordinateLine
            && lhs.placeLine == rhs.placeLine
    }
}

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
        sites.map { site in
            let displayName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName
            return ExploreDiveSiteRowDisplayData(
                id: site.id,
                displayName: displayName,
                diveCountLabel: diveCountLabel(for: site, style: trailingStyle),
                coordinateLine: coordinateLine(for: site),
                placeLine: cityCountryLine(country: site.country, region: site.region).nilIfEmpty
            )
        }
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

    /// Locality + country for list cards — **"Region, Country"** when both are set.
    nonisolated static func cityCountryLine(country: String, region: String) -> String {
        let country = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        if !region.isEmpty, !country.isEmpty {
            return "\(region), \(country)"
        }
        if !region.isEmpty { return region }
        if !country.isEmpty { return country }
        return ""
    }

    nonisolated private static func diveCountLabel(
        for site: DiveSite,
        style: ExploreDiveSiteRowTrailingStyle
    ) -> String? {
        guard style == .catalogDefault else { return nil }
        let diveCount = site.diveActivities.count
        guard diveCount > 0 else { return nil }
        return diveCount == 1 ? "1 dive" : "\(diveCount) dives"
    }

    nonisolated private static func coordinateLine(for site: DiveSite) -> String {
        if let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            return DiveLocationMapPresentation.coordinateLabel(for: coordinate)
        }
        return missingCoordinateLabel
    }

    nonisolated private static let missingCoordinateLabel = "No map pin"
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
