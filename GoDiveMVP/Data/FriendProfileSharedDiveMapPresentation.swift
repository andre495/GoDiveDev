import Foundation

/// Map pins for **FriendProfileView** — blue shared sites, red activities-together (together wins).
enum FriendProfileSharedDiveMapPresentation: Sendable {

    /// Merge friend-shared projections + owner “together” dives; same coordinate prefers red (**together**).
    nonisolated static func pins(
        sharedDives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive],
        togetherDives: [DiveActivity],
        togetherActivityIDs: Set<UUID>,
        catalogSites: [DiveSite],
        currentFirebaseUID: String?
    ) -> [TripDetailMapPin] {
        var togetherKeys = Set<String>()
        var sharedKeys = Set<String>()
        var pinByKey: [String: TripDetailMapPin] = [:]

        for activity in togetherDives {
            guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites),
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { continue }
            let key = coordinateKey(for: coordinate)
            togetherKeys.insert(key)
            let title = activity.resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines)
            pinByKey[key] = TripDetailMapPin(
                id: "friend-together-\(activity.id.uuidString)",
                title: (title?.isEmpty == false) ? title! : "Dive site",
                coordinate: coordinate,
                kind: .friendTogether,
                siteID: activity.diveSiteID
            )
        }

        for dive in sharedDives {
            guard let latitude = dive.entryLatitude,
                  let longitude = dive.entryLongitude
            else { continue }
            let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
            guard DiveMapCoordinateResolver.isUsable(coordinate) else { continue }
            let key = coordinateKey(for: coordinate)
            sharedKeys.insert(key)

            let isTogether = isTogetherSharedDive(
                dive,
                togetherActivityIDs: togetherActivityIDs,
                currentFirebaseUID: currentFirebaseUID
            )
            if isTogether || togetherKeys.contains(key) {
                togetherKeys.insert(key)
                if pinByKey[key]?.kind != .friendTogether {
                    pinByKey[key] = TripDetailMapPin(
                        id: "friend-together-\(dive.id)",
                        title: GoDiveSharedDiveProjectionMapping.displayTitle(for: dive),
                        coordinate: coordinate,
                        kind: .friendTogether,
                        siteID: nil
                    )
                }
                continue
            }

            if !pinByKey.keys.contains(key) {
                pinByKey[key] = TripDetailMapPin(
                    id: "friend-shared-\(dive.id)",
                    title: GoDiveSharedDiveProjectionMapping.displayTitle(for: dive),
                    coordinate: coordinate,
                    kind: .friendShared,
                    siteID: nil
                )
            }
        }

        return pinByKey.values.sorted { $0.id < $1.id }
    }

    nonisolated static func isTogetherSharedDive(
        _ dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive,
        togetherActivityIDs: Set<UUID>,
        currentFirebaseUID: String?
    ) -> Bool {
        if let id = UUID(uuidString: dive.id), togetherActivityIDs.contains(id) {
            return true
        }
        return GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
            dive: dive,
            currentFirebaseUID: currentFirebaseUID
        )
    }

    nonisolated static func accessibilityLabel(for pins: [TripDetailMapPin]) -> String {
        let sharedCount = pins.filter { $0.kind == .friendShared }.count
        let togetherCount = pins.filter { $0.kind == .friendTogether }.count
        switch (sharedCount, togetherCount) {
        case (0, 0):
            return "Friend dive sites map"
        case (_, 0):
            return "Friend dive sites map, \(sharedCount) shared sites"
        case (0, _):
            return "Friend dive sites map, \(togetherCount) sites together"
        default:
            return "Friend dive sites map, \(sharedCount) shared sites, \(togetherCount) sites together"
        }
    }

    private nonisolated static func coordinateKey(for coordinate: DiveCoordinate) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}
