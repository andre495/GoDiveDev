import Foundation

/// Stable, **`Equatable`** Explore list row payload (logbook-style rows).
struct ExploreDiveSiteRowDisplayData: Equatable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let trailingLabel: String?
    let detailLine: String
}

enum ExploreDiveSiteRowTrailingStyle: Sendable {
    /// Explore catalog — rating, dive count, or em dash.
    case catalogDefault
    /// Planned trip saved sites — rating only; omit dive counts.
    case plannedTrip
}

/// Builds Explore dive-site list rows sorted by **`siteName`** (caller supplies sorted sites).
enum ExploreDiveSiteListDisplay {
    static func rowData(
        for sites: [DiveSite],
        trailingStyle: ExploreDiveSiteRowTrailingStyle = .catalogDefault
    ) -> [ExploreDiveSiteRowDisplayData] {
        sites.map { site in
            ExploreDiveSiteRowDisplayData(
                id: site.id,
                displayName: site.siteName,
                trailingLabel: trailingLabel(for: site, style: trailingStyle),
                detailLine: detailLine(for: site)
            )
        }
    }

    /// Place hierarchy for search / list copy (safe from **`nonisolated`** callers).
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

    private static func trailingLabel(
        for site: DiveSite,
        style: ExploreDiveSiteRowTrailingStyle
    ) -> String? {
        if let rating = site.siteRating {
            return "★ \(rating)"
        }
        switch style {
        case .catalogDefault:
            let diveCount = site.diveActivities.count
            if diveCount > 0 {
                return "\(diveCount) dive\(diveCount == 1 ? "" : "s")"
            }
            return "—"
        case .plannedTrip:
            return nil
        }
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
