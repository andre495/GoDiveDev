import CoreGraphics
import CoreLocation
import Foundation

/// Vendor-neutral dive overview map camera for Google Maps (**`GMSCameraPosition`** built in the representable).
enum DiveLocationMapGoogleCameraPresentation: Sendable {
    struct CameraSpec: Equatable, Sendable {
        let centerLatitude: Double
        let centerLongitude: Double
        let zoomLevel: Float
    }

    nonisolated static func cameraSpec(
        coordinate: DiveCoordinate?,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        sheetHeightFraction: CGFloat,
        largeRestingFraction: CGFloat
    ) -> CameraSpec {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else {
            return CameraSpec(
                centerLatitude: DiveLocationMapPresentation.defaultRegion.centerLatitude,
                centerLongitude: DiveLocationMapPresentation.defaultRegion.centerLongitude,
                zoomLevel: 1
            )
        }

        // **`DiveLocationGoogleMapRepresentable`** applies **`GMSMapView.padding`** for top chrome + sheet
        // insets; the camera target stays on the dive coordinate so the pin centers in the visible band.
        let distance = DiveLocationMapPresentation.cameraDistanceMeters(
            sheetHeightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
        let zoom = approximateZoomLevel(atLatitude: coordinate.latitude, viewingDistanceMeters: distance)
        return CameraSpec(
            centerLatitude: coordinate.latitude,
            centerLongitude: coordinate.longitude,
            zoomLevel: zoom
        )
    }

    nonisolated static func cameraSpec(
        coordinate: DiveCoordinate?,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        cameraLayoutDetent: DiveActivityOverviewDetent,
        largeRestingFraction: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
    ) -> CameraSpec {
        let fraction: CGFloat
        switch cameraLayoutDetent {
        case .minimized:
            fraction = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        case .large:
            fraction = largeRestingFraction
        }
        return cameraSpec(
            coordinate: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            sheetHeightFraction: fraction,
            largeRestingFraction: largeRestingFraction
        )
    }

    /// Maps MapKit **`MKMapCamera`** viewing distance to an approximate Google Maps zoom level.
    nonisolated static func approximateZoomLevel(
        atLatitude latitude: Double,
        viewingDistanceMeters: CLLocationDistance
    ) -> Float {
        let latitudeRadians = latitude * .pi / 180
        let metersPerPixel = max(viewingDistanceMeters / 512, 1)
        let rawZoom = log2(156543.03392 * cos(latitudeRadians) / metersPerPixel)
        return Float(min(21, max(1, rawZoom)))
    }
}
