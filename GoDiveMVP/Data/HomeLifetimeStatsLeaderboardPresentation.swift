import Foundation

/// Home lifetime stat tile destinations — ranked top-ten lists with a top-three podium.
enum HomeLifetimeStatsLeaderboardKind: Hashable, Sendable {
    case deepestDives
    case longestDives
    case topSites
    case topSpecies
}

enum HomeLifetimeStatsLeaderboardPresentation {

    nonisolated static let limit = 10
    nonisolated static let podiumLimit = 3

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

    struct SpeciesRowDisplayData: Sendable, Equatable, Identifiable {
        let id: String
        let marineLifeUUID: String
        let commonName: String
        let sightingCountLabel: String
        let featureImageURL: String
        let featureImageResourceName: String
        let showsPreviewImage: Bool
    }

    /// Matches **Dive Buddies** / **Certifications** — title inline with the back button, collides to
    /// **`.headline`** after a short scroll (see **`CollapsibleInlineTitleHeader`**).
    nonisolated static let usesCollapsibleInlineTitleHeader = true

    nonisolated static func pageTitle(for kind: HomeLifetimeStatsLeaderboardKind) -> String {
        switch kind {
        case .deepestDives:
            return "Deepest Dives"
        case .longestDives:
            return "Longest Activities"
        case .topSites:
            return "Top Sites"
        case .topSpecies:
            return "Top Species"
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

    nonisolated static func siteRowDisplayData(
        entry: SiteEntry,
        site: DiveSite?
    ) -> DiveSiteDisplayRecord {
        let visitLabel = HomeLifetimeStatsPresentation.siteVisitLabel(count: entry.visitCount)
        if let site {
            return DiveSitePresentation.listRecord(
                for: site,
                overrideDiveCountLabel: visitLabel
            )
        }
        return importNameSiteRow(name: entry.name, visitCountLabel: visitLabel, entryID: entry.id)
    }

    nonisolated static func speciesRowDisplayData(
        entry: SpeciesEntry,
        featureImageURL: String,
        featureImageResourceName: String
    ) -> SpeciesRowDisplayData {
        return SpeciesRowDisplayData(
            id: entry.id,
            marineLifeUUID: entry.marineLifeUUID,
            commonName: entry.commonName,
            sightingCountLabel: HomeLifetimeStatsPresentation.sightingCountLabel(count: entry.sightingCount),
            featureImageURL: featureImageURL,
            featureImageResourceName: featureImageResourceName,
            showsPreviewImage: hasCatalogPreviewImage(
                featureImageURL: featureImageURL,
                featureImageResourceName: featureImageResourceName
            )
        )
    }

    nonisolated static func hasCatalogPreviewImage(
        featureImageURL: String,
        featureImageResourceName: String
    ) -> Bool {
        FieldGuideMarineLifeBundledImagePresentation.imageSource(
            featureImageResourceName: featureImageResourceName,
            featureImageURL: featureImageURL
        ) != .none
    }

    private nonisolated static func importNameSiteRow(
        name: String,
        visitCountLabel: String,
        entryID: String
    ) -> DiveSiteDisplayRecord {
        DiveSiteDisplayRecord(
            id: deterministicRowID(seed: entryID),
            referenceID: nil,
            catalogSiteID: nil,
            displayName: name,
            country: DiveSitePresentation.missingValue,
            region: DiveSitePresentation.missingValue,
            bodyOfWater: DiveSitePresentation.missingValue,
            coordinateLine: DiveSitePresentation.missingValue,
            entry: DiveSitePresentation.missingValue,
            environment: DiveSitePresentation.missingValue,
            siteType: DiveSitePresentation.missingValue,
            maxDepth: DiveSitePresentation.missingValue,
            rating: DiveSitePresentation.missingValue,
            siteRating: nil,
            waterType: DiveSitePresentation.missingValue,
            divesLogged: visitCountLabel,
            diveCountLabel: visitCountLabel,
            listCountry: DiveSitePresentation.missingValue,
            searchHaystacks: [name],
            searchHaystackLowercased: name.lowercased(),
            isReferenceOnly: false
        )
    }

    private nonisolated static func deterministicRowID(seed: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in seed.utf8.enumerated() {
            bytes[index % 16] ^= byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
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

    nonisolated static func divePodiumMetricLabel(
        dive: HomeDiveStatsInput,
        kind: HomeLifetimeStatsLeaderboardKind,
        unitSystem: DiveDisplayUnitSystem
    ) -> String {
        switch kind {
        case .deepestDives:
            return DiveQuantityFormatting.depth(meters: dive.maxDepthMeters, system: unitSystem)
        case .longestDives:
            return "\(dive.durationMinutes) min"
        case .topSites, .topSpecies:
            return ""
        }
    }

    nonisolated static func divePodiumTitle(for dive: HomeDiveStatsInput) -> String {
        let trimmedSite = dive.siteDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSite.isEmpty, trimmedSite != "New Dive" {
            return trimmedSite
        }
        return dive.diveNumberLabel
    }

    nonisolated static func divePodiumSubtitle(for dive: HomeDiveStatsInput) -> String {
        dive.diveNumberLabel
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
