import Foundation

/// Stable, **`Equatable`** Explore list row payload (logbook-style rows).
struct ExploreDiveSiteRowDisplayData: Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let trailingLabel: String
    let detailLine: String
}

/// Builds Explore dive-site list rows sorted by **`siteName`** (caller supplies sorted sites).
enum ExploreDiveSiteListDisplay {
    static func rowData(for sites: [DiveSite]) -> [ExploreDiveSiteRowDisplayData] {
        sites.map { site in
            ExploreDiveSiteRowDisplayData(
                id: site.id,
                displayName: site.siteName,
                trailingLabel: trailingLabel(for: site),
                detailLine: detailLine(for: site)
            )
        }
    }

    static func placeSummary(for site: DiveSite) -> String {
        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = site.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines)
        return [country, region, body].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func trailingLabel(for site: DiveSite) -> String {
        let diveCount = site.diveActivities.count
        if let rating = site.siteRating {
            return "★ \(rating)"
        }
        if diveCount > 0 {
            return "\(diveCount) dive\(diveCount == 1 ? "" : "s")"
        }
        return "—"
    }

    private static func detailLine(for site: DiveSite) -> String {
        var parts: [String] = []
        let place = placeSummary(for: site)
        if !place.isEmpty {
            parts.append(place)
        }
        if let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            parts.append(DiveLocationMapPresentation.coordinateLabel(for: coordinate))
        } else {
            parts.append("No map pin")
        }
        return parts.joined(separator: " · ")
    }
}
