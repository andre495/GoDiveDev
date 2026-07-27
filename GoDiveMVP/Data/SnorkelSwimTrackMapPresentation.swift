import Foundation
import MapKit

enum SnorkelSwimTrackMapCameraFitting: Sendable, Equatable {
    /// Snorkel detail **Map** tab — fit the track in the visible hero band above the overview sheet.
    case heroBand
    /// Buddy Feed tiles and other short map heroes — tight crop on the GPS track.
    case compact
}

enum SnorkelSwimTrackMapPresentation {

    nonisolated static let singlePointSpanDegrees = 0.002
    nonisolated static let fittingRegionPaddingMultiplier = 1.12
    nonisolated static let fittingMapRectPaddingMultiplier = 1.10
    nonisolated static let minimumSpanDegrees = 0.00035
    nonisolated static let minimumMapRectMeters: Double = 45

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

        let latDelta = max(latSpan * fittingRegionPaddingMultiplier, minimumSpanDegrees)
        let lonDelta = max(lonSpan * fittingRegionPaddingMultiplier, minimumSpanDegrees)
        return DiveLocationMapRegionSpec(
            centerLatitude: centerLat,
            centerLongitude: centerLon,
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
    }

    /// Tight MapKit rect around the swim polyline — preferred for hero camera fitting.
    nonisolated static func fittingMapRect(for coordinates: [DiveCoordinate]) -> MKMapRect? {
        guard !coordinates.isEmpty else { return nil }

        if coordinates.count == 1 {
            return fittingRegion(for: coordinates)?.mkMapRect
        }

        let clCoordinates = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: clCoordinates, count: clCoordinates.count)
        var rect = polyline.boundingMapRect
        guard !rect.isNull else {
            return fittingRegion(for: coordinates)?.mkMapRect
        }

        let expandX = rect.size.width * (fittingMapRectPaddingMultiplier - 1) / 2
        let expandY = rect.size.height * (fittingMapRectPaddingMultiplier - 1) / 2
        rect = rect.insetBy(dx: -expandX, dy: -expandY)

        let centerPoint = MKMapPoint(
            x: rect.midX,
            y: rect.midY
        )
        let metersPerPoint = MKMetersPerMapPointAtLatitude(centerPoint.coordinate.latitude)
        let minDimension = minimumMapRectMeters / metersPerPoint
        if rect.size.width < minDimension {
            let delta = (minDimension - rect.size.width) / 2
            rect = rect.insetBy(dx: -delta, dy: 0)
        }
        if rect.size.height < minDimension {
            let delta = (minDimension - rect.size.height) / 2
            rect = rect.insetBy(dx: 0, dy: -delta)
        }

        return rect
    }

    nonisolated static func cameraEdgePadding(
        fitting: SnorkelSwimTrackMapCameraFitting,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> (top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        switch fitting {
        case .heroBand:
            return (
                top: topObstructionHeight + 12,
                left: 16,
                bottom: bottomContentMargin + 12,
                right: 16
            )
        case .compact:
            return (top: 8, left: 8, bottom: 8, right: 8)
        }
    }

    nonisolated static func mapViewIdentity(activityID: UUID, coordinateCount: Int) -> String {
        "\(activityID.uuidString)-track-\(coordinateCount)"
    }
}
