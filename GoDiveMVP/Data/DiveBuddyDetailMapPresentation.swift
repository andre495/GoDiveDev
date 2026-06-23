import Foundation

/// Dive-site pins for the buddy detail hero map — dives where this buddy is tagged.
enum DiveBuddyDetailMapPresentation: Sendable {

    /// Red completed-style pins for shared dives with a usable map coordinate.
    nonisolated static func pins(
        from sharedDives: [DiveActivity],
        catalogSites: [DiveSite]
    ) -> [TripDetailMapPin] {
        var usedCoordinateKeys = Set<String>()
        var mapPins: [TripDetailMapPin] = []

        for activity in sharedDives {
            guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites),
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { continue }

            let coordinateKey = coordinateKey(for: coordinate)
            guard usedCoordinateKeys.insert(coordinateKey).inserted else { continue }

            let title = activity.resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines)
            mapPins.append(
                TripDetailMapPin(
                    id: "buddy-\(activity.id.uuidString)",
                    title: (title?.isEmpty == false) ? title! : "Dive site",
                    coordinate: coordinate,
                    kind: .completed,
                    siteID: activity.diveSiteID
                )
            )
        }

        return mapPins
    }

    nonisolated static func accessibilityLabel(for pins: [TripDetailMapPin]) -> String {
        switch pins.count {
        case 0:
            return "Buddy dive sites map"
        case 1:
            return "Buddy dive sites map, 1 site"
        default:
            return "Buddy dive sites map, \(pins.count) sites"
        }
    }

    private nonisolated static func coordinateKey(for coordinate: DiveCoordinate) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}
