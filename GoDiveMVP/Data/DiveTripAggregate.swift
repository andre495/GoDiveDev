import Foundation
import SwiftData

/// Read-only dive row for trip aggregate math (tests + builders without touching **`@Model`**).
struct DiveTripDiveSnapshot: Sendable, Equatable {
    let id: UUID
    let startTime: Date
    let durationMinutes: Int
    let maxDepthMeters: Double
    let siteDisplayName: String?
    let diveSiteID: UUID?
    let buddyIDs: [UUID]
    let buddyDisplayNames: [String]
}

/// Read-only sighting row for trip marine-life rollups.
struct DiveTripSightingSnapshot: Sendable, Equatable {
    let marineLifeUUID: String
    let commonName: String
    let diveActivityID: UUID?
}

struct DiveTripLongestDiveSummary: Sendable, Equatable {
    let diveID: UUID
    let durationMinutes: Int
}

struct DiveTripDeepestDiveSummary: Sendable, Equatable {
    let diveID: UUID
    let maxDepthMeters: Double
}

struct DiveTripBuddySummary: Sendable, Equatable, Identifiable {
    var id: UUID { buddyID }
    let buddyID: UUID
    let displayName: String
    let diveCount: Int
}

struct DiveTripMarineLifeSummary: Sendable, Equatable, Identifiable {
    var id: String { marineLifeUUID }
    let marineLifeUUID: String
    let commonName: String
    let sightingCount: Int
}

/// Cached trip rollups — built from linked dives and sightings, not on every SwiftUI pass.
struct DiveTripAggregate: Sendable, Equatable {
    static let empty = DiveTripAggregate(
        diveCount: 0,
        totalDurationMinutes: 0,
        longestDive: nil,
        deepestDive: nil,
        buddies: [],
        marineLife: [],
        visitedSiteNames: [],
        plannedSiteNames: [],
        countries: []
    )

    let diveCount: Int
    let totalDurationMinutes: Int
    let longestDive: DiveTripLongestDiveSummary?
    let deepestDive: DiveTripDeepestDiveSummary?
    let buddies: [DiveTripBuddySummary]
    let marineLife: [DiveTripMarineLifeSummary]
    /// Distinct site names from linked dives (import text or catalog site).
    let visitedSiteNames: [String]
    /// Optional catalog sites attached to the trip plan.
    let plannedSiteNames: [String]
    let countries: [String]
}

enum DiveTripAggregateBuilder: Sendable {

    nonisolated static func build(
        linkedDives: [DiveTripDiveSnapshot],
        sightings: [DiveTripSightingSnapshot],
        plannedSiteNames: [String],
        countries: [String]
    ) -> DiveTripAggregate {
        guard !linkedDives.isEmpty else {
            return DiveTripAggregate(
                diveCount: 0,
                totalDurationMinutes: 0,
                longestDive: nil,
                deepestDive: nil,
                buddies: [],
                marineLife: [],
                visitedSiteNames: [],
                plannedSiteNames: sortedUnique(plannedSiteNames),
                countries: sortedUnique(countries)
            )
        }

        let linkedIDs = Set(linkedDives.map(\.id))
        let totalDuration = linkedDives.reduce(0) { $0 + max(0, $1.durationMinutes) }

        let longest = linkedDives.max(by: { lhs, rhs in
            if lhs.durationMinutes != rhs.durationMinutes {
                return lhs.durationMinutes < rhs.durationMinutes
            }
            return lhs.startTime > rhs.startTime
        })

        let deepest = linkedDives.max(by: { lhs, rhs in
            if lhs.maxDepthMeters != rhs.maxDepthMeters {
                return lhs.maxDepthMeters < rhs.maxDepthMeters
            }
            return lhs.startTime > rhs.startTime
        })

        return DiveTripAggregate(
            diveCount: linkedDives.count,
            totalDurationMinutes: totalDuration,
            longestDive: longest.map {
                DiveTripLongestDiveSummary(diveID: $0.id, durationMinutes: $0.durationMinutes)
            },
            deepestDive: deepest.map {
                DiveTripDeepestDiveSummary(diveID: $0.id, maxDepthMeters: $0.maxDepthMeters)
            },
            buddies: buddySummaries(from: linkedDives),
            marineLife: marineLifeSummaries(
                sightings: sightings,
                linkedDiveIDs: linkedIDs
            ),
            visitedSiteNames: visitedSiteNames(from: linkedDives),
            plannedSiteNames: sortedUnique(plannedSiteNames),
            countries: sortedUnique(countries)
        )
    }

    /// Materialize snapshots from persisted models (call on main actor).
    @MainActor
    static func snapshots(from activities: [DiveActivity]) -> [DiveTripDiveSnapshot] {
        activities.map { activity in
            DiveTripDiveSnapshot(
                id: activity.id,
                startTime: activity.startTime,
                durationMinutes: activity.durationMinutes,
                maxDepthMeters: activity.maxDepthMeters,
                siteDisplayName: activity.resolvedSiteName ?? activity.siteName,
                diveSiteID: activity.diveSiteID,
                buddyIDs: activity.buddies.compactMap(\.buddyID),
                buddyDisplayNames: activity.buddies.map(\.displayName)
            )
        }
    }

    @MainActor
    static func sightingSnapshots(
        from sightings: [SightingInstance],
        marineLifeCatalog: [MarineLife]
    ) -> [DiveTripSightingSnapshot] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: marineLifeCatalog.map { ($0.uuid, $0) })
        return sightings.map { sighting in
            let name = catalogByUUID[sighting.marineLifeUUID]?.commonName
                ?? sighting.marineLifeUUID
            return DiveTripSightingSnapshot(
                marineLifeUUID: sighting.marineLifeUUID,
                commonName: name,
                diveActivityID: sighting.diveActivityID
            )
        }
    }

    @MainActor
    static func build(
        trip: DiveTrip,
        marineLifeCatalog: [MarineLife],
        allSightings: [SightingInstance]
    ) -> DiveTripAggregate {
        let dives = snapshots(from: trip.linkedActivities)
        let sightings = sightingSnapshots(from: allSightings, marineLifeCatalog: marineLifeCatalog)
        let plannedNames: [String] = {
            guard let modelContext = trip.modelContext else { return [] }
            return trip.plannedSiteIDs.compactMap {
                try? DiveLinkedSiteResolver.resolve(id: $0, modelContext: modelContext)?.siteName
            }
        }()
        return build(
            linkedDives: dives,
            sightings: sightings,
            plannedSiteNames: plannedNames,
            countries: trip.countries
        )
    }

    // MARK: - Private

    private nonisolated static func buddySummaries(
        from dives: [DiveTripDiveSnapshot]
    ) -> [DiveTripBuddySummary] {
        var counts: [UUID: (name: String, dives: Int)] = [:]
        for dive in dives {
            for (index, buddyID) in dive.buddyIDs.enumerated() {
                let name = dive.buddyDisplayNames.indices.contains(index)
                    ? dive.buddyDisplayNames[index]
                    : "Buddy"
                if var existing = counts[buddyID] {
                    existing.dives += 1
                    counts[buddyID] = existing
                } else {
                    counts[buddyID] = (name, 1)
                }
            }
        }
        return counts
            .map { DiveTripBuddySummary(buddyID: $0.key, displayName: $0.value.name, diveCount: $0.value.dives) }
            .sorted {
                if $0.diveCount != $1.diveCount { return $0.diveCount > $1.diveCount }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private nonisolated static func marineLifeSummaries(
        sightings: [DiveTripSightingSnapshot],
        linkedDiveIDs: Set<UUID>
    ) -> [DiveTripMarineLifeSummary] {
        var counts: [String: (name: String, count: Int)] = [:]
        for sighting in sightings {
            guard let diveID = sighting.diveActivityID, linkedDiveIDs.contains(diveID) else { continue }
            if var existing = counts[sighting.marineLifeUUID] {
                existing.count += 1
                counts[sighting.marineLifeUUID] = existing
            } else {
                counts[sighting.marineLifeUUID] = (sighting.commonName, 1)
            }
        }
        return counts
            .map {
                DiveTripMarineLifeSummary(
                    marineLifeUUID: $0.key,
                    commonName: $0.value.name,
                    sightingCount: $0.value.count
                )
            }
            .sorted {
                if $0.sightingCount != $1.sightingCount { return $0.sightingCount > $1.sightingCount }
                return $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
            }
    }

    private nonisolated static func visitedSiteNames(from dives: [DiveTripDiveSnapshot]) -> [String] {
        sortedUnique(
            dives.compactMap { dive in
                let trimmed = dive.siteDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private nonisolated static func sortedUnique(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
