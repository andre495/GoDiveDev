import Foundation

/// Home lifetime stat tile destinations — ranked top-five lists.
enum HomeLifetimeStatsLeaderboardKind: Hashable, Sendable {
    case deepestDives
    case longestDives
    case topSites
    case topSpecies
}

enum HomeLifetimeStatsLeaderboardPresentation {

    nonisolated static let limit = 5

    struct SiteEntry: Sendable, Equatable, Identifiable {
        let id: String
        let rank: Int
        let siteID: UUID?
        let name: String
        let visitCount: Int
    }

    struct SpeciesEntry: Sendable, Equatable, Identifiable {
        let id: String
        let rank: Int
        let marineLifeUUID: String
        let commonName: String
        let sightingCount: Int
    }

    nonisolated static func pageTitle(for kind: HomeLifetimeStatsLeaderboardKind) -> String {
        switch kind {
        case .deepestDives:
            return "Top 5 deepest dives"
        case .longestDives:
            return "Top 5 longest dives"
        case .topSites:
            return "Top 5 dive sites"
        case .topSpecies:
            return "Top 5 species"
        }
    }

    nonisolated static func rankedDiveIDs(
        dives: [HomeDiveStatsInput],
        kind: HomeLifetimeStatsLeaderboardKind
    ) -> [UUID] {
        switch kind {
        case .deepestDives:
            return dives
                .sorted { lhs, rhs in
                    if lhs.maxDepthMeters != rhs.maxDepthMeters {
                        return lhs.maxDepthMeters > rhs.maxDepthMeters
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                .prefix(limit)
                .map(\.id)
        case .longestDives:
            return dives
                .sorted { lhs, rhs in
                    if lhs.durationMinutes != rhs.durationMinutes {
                        return lhs.durationMinutes > rhs.durationMinutes
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                .prefix(limit)
                .map(\.id)
        case .topSites, .topSpecies:
            return []
        }
    }

    nonisolated static func topSites(dives: [HomeDiveStatsInput]) -> [SiteEntry] {
        let grouped = siteVisitCounts(for: dives)
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.key.displayName.localizedCaseInsensitiveCompare(rhs.key.displayName) == .orderedAscending
            }
            .prefix(limit)

        return grouped.enumerated().map { index, item in
            SiteEntry(
                id: siteEntryID(siteID: item.key.siteID, normalizedName: item.key.normalizedName),
                rank: index + 1,
                siteID: item.key.siteID,
                name: item.key.displayName,
                visitCount: item.count
            )
        }
    }

    nonisolated static func topSpecies(
        sightings: [HomeLifetimeStatsPresentation.SightingCountInput]
    ) -> [SpeciesEntry] {
        let counts = Dictionary(grouping: sightings, by: \.marineLifeUUID).mapValues(\.count)
        let ranked = counts.keys.sorted { lhs, rhs in
            let leftCount = counts[lhs, default: 0]
            let rightCount = counts[rhs, default: 0]
            if leftCount != rightCount { return leftCount > rightCount }
            let leftName = sightings.first(where: { $0.marineLifeUUID == lhs })?.commonName ?? lhs
            let rightName = sightings.first(where: { $0.marineLifeUUID == rhs })?.commonName ?? rhs
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
        .prefix(limit)

        return ranked.enumerated().map { index, marineLifeUUID in
            let count = counts[marineLifeUUID, default: 0]
            let name = sightings.first(where: { $0.marineLifeUUID == marineLifeUUID })?.commonName
                ?? marineLifeUUID
            return SpeciesEntry(
                id: marineLifeUUID,
                rank: index + 1,
                marineLifeUUID: marineLifeUUID,
                commonName: name,
                sightingCount: count
            )
        }
    }

    nonisolated static func metricCaption(for kind: HomeLifetimeStatsLeaderboardKind, count: Int) -> String {
        switch kind {
        case .deepestDives, .longestDives:
            return ""
        case .topSites:
            return HomeLifetimeStatsPresentation.siteVisitLabel(count: count)
        case .topSpecies:
            return HomeLifetimeStatsPresentation.sightingCountLabel(count: count)
        }
    }

    private nonisolated static func siteEntryID(siteID: UUID?, normalizedName: String) -> String {
        if let siteID {
            return siteID.uuidString
        }
        return "name:\(normalizedName)"
    }

    private nonisolated static func siteVisitCounts(
        for dives: [HomeDiveStatsInput]
    ) -> [(key: HomeLifetimeStatsLeaderboardSiteKey, count: Int)] {
        var groups: [(key: HomeLifetimeStatsLeaderboardSiteKey, count: Int)] = []
        for dive in dives {
            guard let key = HomeLifetimeStatsLeaderboardSiteKey(dive: dive) else { continue }
            if let index = groups.firstIndex(where: { $0.key.isSameSite(as: key) }) {
                groups[index].count += 1
            } else {
                groups.append((key: key, count: 1))
            }
        }
        return groups
    }
}

private struct HomeLifetimeStatsLeaderboardSiteKey: Sendable {
    let siteID: UUID?
    let displayName: String
    let normalizedName: String

    nonisolated init?(dive: HomeDiveStatsInput) {
        let trimmed = dive.siteDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "New Dive" else { return nil }
        siteID = dive.diveSiteID
        displayName = trimmed
        normalizedName = trimmed.lowercased()
    }

    nonisolated func isSameSite(as other: Self) -> Bool {
        if let siteID, let otherSiteID = other.siteID {
            return siteID == otherSiteID
        }
        return normalizedName == other.normalizedName
    }
}
