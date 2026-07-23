import Foundation

enum SnorkelSwimTrackMapPresentation {

    private nonisolated static let singlePointSpanDegrees = 0.004
    private nonisolated static let paddingMultiplier = 1.35
    private nonisolated static let minimumSpanDegrees = 0.0008

    nonisolated static func fittingRegion(for coordinates: [DiveCoordinate]) -> DiveLocationMapRegionSpec? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon

        if coordinates.count == 1 || (latSpan < 1e-9 && lonSpan < 1e-9) {
            return DiveLocationMapRegionSpec(
                centerLatitude: centerLat,
                centerLongitude: centerLon,
                latitudeDelta: singlePointSpanDegrees,
                longitudeDelta: singlePointSpanDegrees
            )
        }

        let latDelta = max(latSpan * paddingMultiplier, minimumSpanDegrees)
        let lonDelta = max(lonSpan * paddingMultiplier, minimumSpanDegrees)
        return DiveLocationMapRegionSpec(
            centerLatitude: centerLat,
            centerLongitude: centerLon,
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
    }

    nonisolated static func mapViewIdentity(activityID: UUID, coordinateCount: Int) -> String {
        "\(activityID.uuidString)-track-\(coordinateCount)"
    }
}
