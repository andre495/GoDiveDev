import Foundation

/// Map pins for **FriendProfileView** from friend-visible dive projections.
enum FriendProfileSharedDiveMapPresentation: Sendable {

    nonisolated static func pins(
        from dives: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    ) -> [TripDetailMapPin] {
        var usedCoordinateKeys = Set<String>()
        var mapPins: [TripDetailMapPin] = []

        for dive in dives {
            guard let latitude = dive.entryLatitude,
                  let longitude = dive.entryLongitude
            else { continue }
            let coordinate = DiveCoordinate(latitude: latitude, longitude: longitude)
            guard DiveMapCoordinateResolver.isUsable(coordinate) else { continue }

            let coordinateKey = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
            guard usedCoordinateKeys.insert(coordinateKey).inserted else { continue }

            let title = GoDiveSharedDiveProjectionMapping.displayTitle(for: dive)
            mapPins.append(
                TripDetailMapPin(
                    id: "friend-dive-\(dive.id)",
                    title: title,
                    coordinate: coordinate,
                    kind: .completed,
                    siteID: nil
                )
            )
        }
        return mapPins
    }
}
