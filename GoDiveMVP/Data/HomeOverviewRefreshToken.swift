import Foundation

/// Cheap change detector so Home carousel + stats recompute when logbook data changes (count or edited metrics).
enum HomeOverviewRefreshToken {

    nonisolated static func make(
        dives: [HomeDiveStatsInput],
        buddyTags: [HomeBuddyLeaderboardPresentation.TagInput] = [],
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
        let buddyPart = buddyTags
            .sorted {
                ($0.buddyID.uuidString, $0.diveActivityID.uuidString)
                    < ($1.buddyID.uuidString, $1.diveActivityID.uuidString)
            }
            .map {
                "\($0.buddyID.uuidString):\($0.diveActivityID.uuidString):\($0.displayName)"
            }
            .joined(separator: "|")
        return "d=\(divePart)#b=\(buddyPart)#s=\(sightingCount)#m=\(mediaCount)"
    }
}
