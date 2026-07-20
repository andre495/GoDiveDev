import Foundation
import SwiftData

/// Merges duplicate pure-custom **`UserDiveSite`** rows that share an owner + exact site name.
///
/// Older imports created one user site per dive for unmatched names; consolidation heals that so
/// Explore / Top Sites show one row with the full dive count.
enum UserDiveSiteDuplicateConsolidation: Sendable {

    struct Result: Equatable, Sendable {
        let mergedGroupCount: Int
        let deletedSiteCount: Int
        let relinkedDiveCount: Int

        static let empty = Result(mergedGroupCount: 0, deletedSiteCount: 0, relinkedDiveCount: 0)

        var didChange: Bool {
            mergedGroupCount > 0 || deletedSiteCount > 0 || relinkedDiveCount > 0
        }
    }

    /// Idempotent — safe to run on every launch.
    @discardableResult
    static func consolidateIfNeeded(modelContext: ModelContext) throws -> Result {
        let sites = try modelContext.fetch(FetchDescriptor<UserDiveSite>())
        let customSites = sites.filter { isPureCustom($0) }
        guard !customSites.isEmpty else { return .empty }

        var groups: [String: [UserDiveSite]] = [:]
        for site in customSites {
            guard let key = groupKey(for: site) else { continue }
            groups[key, default: []].append(site)
        }

        let activities = try modelContext.fetch(FetchDescriptor<DiveActivity>())
        var diveCountBySiteID: [UUID: Int] = [:]
        for activity in activities {
            guard let siteID = activity.diveSiteID else { continue }
            diveCountBySiteID[siteID, default: 0] += 1
        }
        let sightings = try modelContext.fetch(FetchDescriptor<SightingInstance>())
        let trips = try modelContext.fetch(FetchDescriptor<DiveTrip>())

        var mergedGroupCount = 0
        var deletedSiteCount = 0
        var relinkedDiveCount = 0

        for (_, group) in groups where group.count > 1 {
            let canonical = pickCanonical(from: group, diveCountBySiteID: diveCountBySiteID)
            let duplicateIDs = Set(group.map(\.id).filter { $0 != canonical.id })
            guard !duplicateIDs.isEmpty else { continue }

            mergedGroupCount += 1

            for activity in activities where activity.diveSiteID.map(duplicateIDs.contains) == true {
                activity.diveSiteID = canonical.id
                relinkedDiveCount += 1
            }

            for sighting in sightings where sighting.diveSiteID.map(duplicateIDs.contains) == true {
                sighting.diveSiteID = canonical.id
            }

            for trip in trips {
                let planned = trip.plannedSiteIDs
                guard planned.contains(where: duplicateIDs.contains) else { continue }
                var rewritten: [UUID] = []
                var seen = Set<UUID>()
                for id in planned {
                    let next = duplicateIDs.contains(id) ? canonical.id : id
                    if seen.insert(next).inserted {
                        rewritten.append(next)
                    }
                }
                trip.plannedSiteIDs = rewritten
            }

            for site in group where site.id != canonical.id {
                fillMissingMetadata(on: canonical, from: site)
                modelContext.delete(site)
                deletedSiteCount += 1
            }
        }

        let result = Result(
            mergedGroupCount: mergedGroupCount,
            deletedSiteCount: deletedSiteCount,
            relinkedDiveCount: relinkedDiveCount
        )
        if result.didChange {
            try modelContext.save()
            DiveSiteLinksChangeNotification.post()
        }
        return result
    }

    private static func isPureCustom(_ site: UserDiveSite) -> Bool {
        site.openDiveMapReferenceID == nil && site.catalogDiveSiteID == nil
    }

    private static func groupKey(for site: UserDiveSite) -> String? {
        let trimmed = site.siteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let ownerKey = site.ownerProfileID?.uuidString ?? "nil"
        return "\(ownerKey)|\(trimmed.lowercased())"
    }

    private static func pickCanonical(
        from group: [UserDiveSite],
        diveCountBySiteID: [UUID: Int]
    ) -> UserDiveSite {
        group.sorted { lhs, rhs in
            let leftCount = diveCountBySiteID[lhs.id, default: 0]
            let rightCount = diveCountBySiteID[rhs.id, default: 0]
            if leftCount != rightCount { return leftCount > rightCount }

            let leftHasCoords = lhs.latCoords != nil && lhs.longCoords != nil
            let rightHasCoords = rhs.latCoords != nil && rhs.longCoords != nil
            if leftHasCoords != rightHasCoords { return leftHasCoords }

            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }[0]
    }

    private static func fillMissingMetadata(on canonical: UserDiveSite, from duplicate: UserDiveSite) {
        if (canonical.latCoords == nil || canonical.longCoords == nil),
           let lat = duplicate.latCoords,
           let lon = duplicate.longCoords {
            canonical.latCoords = lat
            canonical.longCoords = lon
        }
        if canonical.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.country = duplicate.country
        }
        if canonical.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.region = duplicate.region
        }
        if canonical.bodyOfWater.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.bodyOfWater = duplicate.bodyOfWater
        }
        if canonical.owner == nil, let owner = duplicate.owner {
            canonical.owner = owner
            canonical.ownerProfileID = owner.id
        }
        canonical.updatedAt = Date()
    }
}
