import Foundation

/// Cheap change detector so Home carousel + stats recompute when logbook data changes (count or edited metrics).
enum HomeOverviewRefreshToken {

    nonisolated static func make(
        dives: [HomeDiveStatsInput],
        sightingCount: Int,
        mediaCount: Int
    ) -> String {
        let divePart = dives
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { dive in
                [
                    dive.id.uuidString,
                    String(dive.maxDepthMeters),
                    String(dive.durationMinutes),
                    dive.diveSiteID?.uuidString ?? "",
                    dive.siteDisplayName,
                ].joined(separator: ":")
            }
            .joined(separator: "|")
        return "d=\(divePart)#s=\(sightingCount)#m=\(mediaCount)"
    }
}
