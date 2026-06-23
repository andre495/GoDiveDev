import Foundation

/// Dive-site pins for the species detail hero map — sites from dives where this species is tagged.
enum FieldGuideSpeciesDetailMapPresentation: Sendable {

    /// Red completed-style pins for tagged dives with a usable map coordinate (one pin per coordinate).
    nonisolated static func pins(
        from taggedDives: [DiveActivity],
        catalogSites: [DiveSite]
    ) -> [TripDetailMapPin] {
        var usedCoordinateKeys = Set<String>()
        var mapPins: [TripDetailMapPin] = []

        for activity in taggedDives {
            guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites),
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { continue }

            let coordinateKey = coordinateKey(for: coordinate)
            guard usedCoordinateKeys.insert(coordinateKey).inserted else { continue }

            let title = activity.resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines)
            mapPins.append(
                TripDetailMapPin(
                    id: "species-\(activity.id.uuidString)",
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
            return "Species sighting sites map"
        case 1:
            return "Species sighting sites map, 1 site"
        default:
            return "Species sighting sites map, \(pins.count) sites"
        }
    }

    private nonisolated static func coordinateKey(for coordinate: DiveCoordinate) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}
