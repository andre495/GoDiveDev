import Foundation

/// Lifetime highlight stats for a friend profile — built from shared dive projections only.
enum FriendProfileLifetimeStatsPresentation: Sendable {

    nonisolated static func build(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive],
        commonNameByUUID: [String: String] = [:]
    ) -> HomeLifetimeStats {
        HomeLifetimeStatsPresentation.build(
            dives: diveStatsInputs(from: dives),
            sightings: sightingInputs(from: dives, commonNameByUUID: commonNameByUUID)
        )
    }

    /// Scuba shared dives with depth and duration (snorkels feed site/species via sightings only).
    nonisolated static func diveStatsInputs(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> [HomeDiveStatsInput] {
        dives.compactMap { dive in
            guard dive.resolvedActivityKind == .scubaDive else { return nil }
            guard let id = UUID(uuidString: dive.id) else { return nil }
            let depth = dive.maxDepthMeters ?? 0
            let minutes = dive.durationMinutes ?? 0
            guard depth > 0 || minutes > 0 else { return nil }
            let numberLabel: String
            if let number = dive.diveNumber {
                numberLabel = "#\(number)"
            } else {
                numberLabel = "#"
            }
            return HomeDiveStatsInput(
                id: id,
                maxDepthMeters: depth,
                durationMinutes: minutes,
                diveSiteID: nil,
                diveNumberLabel: numberLabel,
                // Untitled → **New Dive** so top-site aggregation skips them (same as Home).
                siteDisplayName: siteDisplayNameForStats(dive)
            )
        }
    }

    /// Prefer site / location; generic untitled labels do not compete for **Top site**.
    nonisolated static func siteDisplayNameForStats(
        _ dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    ) -> String {
        let site = dive.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !site.isEmpty { return site }
        let location = dive.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !location.isEmpty { return location }
        return "New Dive"
    }

    nonisolated static func sightingInputs(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive],
        commonNameByUUID: [String: String] = [:]
    ) -> [HomeLifetimeStatsPresentation.SightingCountInput] {
        dives.flatMap { dive in
            dive.sightings.compactMap { sighting -> HomeLifetimeStatsPresentation.SightingCountInput? in
                let name = GoDiveSharedDiveProjectionMapping.resolvedSightingCommonName(
                    storedCommonName: sighting.commonName,
                    catalogUUID: sighting.catalogUUID,
                    commonNameByUUID: commonNameByUUID
                )
                guard !name.isEmpty else { return nil }
                let key = sighting.catalogUUID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let marineLifeUUID = key.isEmpty ? name.lowercased() : key
                return HomeLifetimeStatsPresentation.SightingCountInput(
                    marineLifeUUID: marineLifeUUID,
                    commonName: name
                )
            }
        }
    }
}
