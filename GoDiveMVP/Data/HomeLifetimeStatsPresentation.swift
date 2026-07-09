import Foundation

/// One owned dive row for lifetime stat aggregation (no SwiftData models — safe off the main actor).
struct HomeDiveStatsInput: Sendable, Equatable {
    let id: UUID
    let maxDepthMeters: Double
    let durationMinutes: Int
    let diveSiteID: UUID?
    let diveNumberLabel: String
    let siteDisplayName: String
    let linkedTripID: UUID?
    let linkedTripTitle: String?
    let linkedTripAccentColorIndex: Int?

    nonisolated init(
        id: UUID,
        maxDepthMeters: Double,
        durationMinutes: Int,
        diveSiteID: UUID?,
        diveNumberLabel: String,
        siteDisplayName: String,
        linkedTripID: UUID? = nil,
        linkedTripTitle: String? = nil,
        linkedTripAccentColorIndex: Int? = nil
    ) {
        self.id = id
        self.maxDepthMeters = maxDepthMeters
        self.durationMinutes = durationMinutes
        self.diveSiteID = diveSiteID
        self.diveNumberLabel = diveNumberLabel
        self.siteDisplayName = siteDisplayName
        self.linkedTripID = linkedTripID
        self.linkedTripTitle = linkedTripTitle
        self.linkedTripAccentColorIndex = linkedTripAccentColorIndex
    }
}

/// Aggregated lifetime stats across the signed-in diver's logbook.
struct HomeLifetimeStats: Equatable, Sendable {
    struct LinkedDive: Equatable, Sendable {
        let id: UUID
        let siteDisplayName: String
    }

    struct LinkedSite: Equatable, Sendable {
        /// Catalog **`DiveSite.id`** when the top site is linked; **`nil`** for import-only site names.
        let id: UUID?
        let name: String
        let visitCount: Int
    }

    struct LinkedSpecies: Equatable, Sendable {
        let marineLifeUUID: String
        let commonName: String
        let sightingCount: Int
    }

    let diveCount: Int
    let averageMaxDepthMeters: Double?
    let averageDurationMinutes: Double?
    let deepestDive: LinkedDive?
    let deepestMaxDepthMeters: Double?
    let longestDive: LinkedDive?
    let longestDurationMinutes: Int?
    let mostVisitedSite: LinkedSite?
    let topSpecies: LinkedSpecies?

}

/// Site visit grouping for top-site stats. No **Hashable** — Swift 6 infers MainActor on nested conformances used from SwiftUI.
private struct HomeSiteVisitKey: Sendable {
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

/// Builds Home tab lifetime stats from owned dives and optional sighting rows.
enum HomeLifetimeStatsPresentation {

    nonisolated static let topSpeciesEmptyValue = "—"
    nonisolated static let topSpeciesEmptyFootnote = "Tag marine life on your dives"

    nonisolated static let emptyStatValue = "—"
    nonisolated static let deepestEmptyFootnote = "Log dives to track your deepest"
    nonisolated static let longestEmptyFootnote = "Log dives to track bottom time"
    nonisolated static let topSiteEmptyFootnote = "Visit sites to see your favorite"

    /// Read-only tile copy for the Home lifetime stats grid (always four tiles).
    struct HighlightStatTileDescriptor: Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let value: String
        let footnote: String
        let systemImage: String
        let leaderboardKind: HomeLifetimeStatsLeaderboardKind?
    }

    nonisolated static func highlightStatTileDescriptors(
        stats: HomeLifetimeStats,
        unitSystem: DiveDisplayUnitSystem
    ) -> [HighlightStatTileDescriptor] {
        [
            deepestTileDescriptor(stats: stats, unitSystem: unitSystem),
            longestTileDescriptor(stats: stats),
            topSiteTileDescriptor(stats: stats),
            topSpeciesTileDescriptor(stats: stats),
        ]
    }

    private nonisolated static func deepestTileDescriptor(
        stats: HomeLifetimeStats,
        unitSystem: DiveDisplayUnitSystem
    ) -> HighlightStatTileDescriptor {
        if let deepest = stats.deepestDive, let depth = stats.deepestMaxDepthMeters {
            return HighlightStatTileDescriptor(
                id: "deepest",
                title: "Deepest",
                value: DiveQuantityFormatting.depth(meters: depth, system: unitSystem),
                footnote: deepest.siteDisplayName,
                systemImage: "arrow.down.circle.fill",
                leaderboardKind: .deepestDives
            )
        }
        return HighlightStatTileDescriptor(
            id: "deepest",
            title: "Deepest",
            value: emptyStatValue,
            footnote: deepestEmptyFootnote,
            systemImage: "arrow.down.circle.fill",
            leaderboardKind: nil
        )
    }

    private nonisolated static func longestTileDescriptor(stats: HomeLifetimeStats) -> HighlightStatTileDescriptor {
        if let longest = stats.longestDive, let minutes = stats.longestDurationMinutes {
            return HighlightStatTileDescriptor(
                id: "longest",
                title: "Longest",
                value: formattedDuration(minutes: minutes),
                footnote: longest.siteDisplayName,
                systemImage: "clock.fill",
                leaderboardKind: .longestDives
            )
        }
        return HighlightStatTileDescriptor(
            id: "longest",
            title: "Longest",
            value: emptyStatValue,
            footnote: longestEmptyFootnote,
            systemImage: "clock.fill",
            leaderboardKind: nil
        )
    }

    private nonisolated static func topSiteTileDescriptor(stats: HomeLifetimeStats) -> HighlightStatTileDescriptor {
        if let site = stats.mostVisitedSite {
            return HighlightStatTileDescriptor(
                id: "top-site",
                title: "Top site",
                value: site.name,
                footnote: siteVisitLabel(count: site.visitCount),
                systemImage: "mappin.circle.fill",
                leaderboardKind: .topSites
            )
        }
        return HighlightStatTileDescriptor(
            id: "top-site",
            title: "Top site",
            value: emptyStatValue,
            footnote: topSiteEmptyFootnote,
            systemImage: "mappin.circle.fill",
            leaderboardKind: nil
        )
    }

    private nonisolated static func topSpeciesTileDescriptor(stats: HomeLifetimeStats) -> HighlightStatTileDescriptor {
        if let species = stats.topSpecies {
            return HighlightStatTileDescriptor(
                id: "top-species",
                title: "Top species",
                value: species.commonName,
                footnote: sightingCountLabel(count: species.sightingCount),
                systemImage: "fish.fill",
                leaderboardKind: .topSpecies
            )
        }
        return HighlightStatTileDescriptor(
            id: "top-species",
            title: "Top species",
            value: topSpeciesEmptyValue,
            footnote: topSpeciesEmptyFootnote,
            systemImage: "fish.fill",
            leaderboardKind: nil
        )
    }

    struct SightingCountInput: Sendable, Equatable {
        let marineLifeUUID: String
        let commonName: String
    }

    nonisolated static func build(
        dives: [HomeDiveStatsInput],
        sightings: [SightingCountInput]
    ) -> HomeLifetimeStats {
        guard !dives.isEmpty else { return emptyStats() }

        let diveCount = dives.count
        let averageMaxDepthMeters = dives.map(\.maxDepthMeters).reduce(0, +) / Double(diveCount)
        let averageDurationMinutes = Double(dives.map(\.durationMinutes).reduce(0, +)) / Double(diveCount)

        let deepest = dives.max { $0.maxDepthMeters < $1.maxDepthMeters }
        let longest = dives.max { $0.durationMinutes < $1.durationMinutes }

        let siteCounts = siteVisitCounts(for: dives)
        let topSite = siteCounts.max { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count < rhs.count }
            return lhs.key.displayName.localizedCaseInsensitiveCompare(rhs.key.displayName) == .orderedDescending
        }

        let speciesCounts = Dictionary(grouping: sightings, by: \.marineLifeUUID)
            .mapValues(\.count)
        let topSpeciesKey = speciesCounts.max { $0.value < $1.value }?.key
        let topSpecies: HomeLifetimeStats.LinkedSpecies?
        if let topSpeciesKey,
           let count = speciesCounts[topSpeciesKey],
           let name = sightings.first(where: { $0.marineLifeUUID == topSpeciesKey })?.commonName {
            topSpecies = HomeLifetimeStats.LinkedSpecies(
                marineLifeUUID: topSpeciesKey,
                commonName: name,
                sightingCount: count
            )
        } else {
            topSpecies = nil
        }

        return HomeLifetimeStats(
            diveCount: diveCount,
            averageMaxDepthMeters: averageMaxDepthMeters,
            averageDurationMinutes: averageDurationMinutes,
            deepestDive: deepest.map { HomeLifetimeStats.LinkedDive(id: $0.id, siteDisplayName: $0.siteDisplayName) },
            deepestMaxDepthMeters: deepest?.maxDepthMeters,
            longestDive: longest.map { HomeLifetimeStats.LinkedDive(id: $0.id, siteDisplayName: $0.siteDisplayName) },
            longestDurationMinutes: longest?.durationMinutes,
            mostVisitedSite: topSite.map {
                HomeLifetimeStats.LinkedSite(id: $0.key.siteID, name: $0.key.displayName, visitCount: $0.count)
            },
            topSpecies: topSpecies
        )
    }

    nonisolated static func diveCountLabel(_ count: Int) -> String {
        count == 1 ? "1 dive" : "\(count) dives"
    }

    nonisolated static func formattedAverageDuration(minutes: Double?) -> String {
        guard let minutes, minutes > 0 else { return "—" }
        let rounded = minutes.rounded()
        if rounded >= 60 {
            let whole = Int(rounded)
            let hours = whole / 60
            let remainder = whole % 60
            return remainder > 0 ? "\(hours) hr \(remainder) min" : "\(hours) hr"
        }
        return "\(Int(rounded)) min"
    }

    nonisolated static func formattedDuration(minutes: Int) -> String {
        formattedAverageDuration(minutes: Double(minutes))
    }

    /// Combined depth + bottom time for the **Average dive** stat tile.
    nonisolated static func formattedAverageDiveSummary(
        depthMeters: Double?,
        durationMinutes: Double?,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        let depthPart: String
        if let depthMeters, depthMeters > 0 {
            depthPart = DiveQuantityFormatting.depth(meters: depthMeters, system: unitSystem)
        } else {
            depthPart = "—"
        }
        let durationPart = formattedAverageDuration(minutes: durationMinutes)
        if depthPart == "—", durationPart == "—" { return "—" }
        if depthPart == "—" { return durationPart }
        if durationPart == "—" { return depthPart }
        return "\(depthPart) · \(durationPart)"
    }

    nonisolated static func siteVisitLabel(count: Int) -> String {
        count == 1 ? "1 visit" : "\(count) visits"
    }

    nonisolated static func sightingCountLabel(count: Int) -> String {
        count == 1 ? "1 sighting" : "\(count) sightings"
    }

    private nonisolated static func emptyStats() -> HomeLifetimeStats {
        HomeLifetimeStats(
            diveCount: 0,
            averageMaxDepthMeters: nil,
            averageDurationMinutes: nil,
            deepestDive: nil,
            deepestMaxDepthMeters: nil,
            longestDive: nil,
            longestDurationMinutes: nil,
            mostVisitedSite: nil,
            topSpecies: nil
        )
    }

    private nonisolated static func siteVisitCounts(
        for dives: [HomeDiveStatsInput]
    ) -> [(key: HomeSiteVisitKey, count: Int)] {
        var groups: [(key: HomeSiteVisitKey, count: Int)] = []
        for dive in dives {
            guard let key = HomeSiteVisitKey(dive: dive) else { continue }
            if let index = groups.firstIndex(where: { $0.key.isSameSite(as: key) }) {
                groups[index].count += 1
            } else {
                groups.append((key: key, count: 1))
            }
        }
        return groups
    }
}
