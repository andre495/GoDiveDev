import CoreGraphics
import MapKit

/// Region and formatting for the add-dive-site coordinate picker map.
enum DiveSiteCoordinatePickerPresentation: Sendable {
    nonisolated static let pickerLatitudeDelta: CGFloat = 0.04
    nonisolated static let pickerLongitudeDelta: CGFloat = 0.04

    nonisolated static let defaultCenter = DiveCoordinate(latitude: 20, longitude: 0)

    nonisolated static func initialCenter(
        latitudeText: String,
        longitudeText: String,
        fallback: DiveCoordinate? = nil
    ) -> DiveCoordinate {
        if let parsed = DiveSiteFormValidation.parsedCoordinate(
            latitudeText: latitudeText,
            longitudeText: longitudeText
        ) {
            return parsed
        }
        if let fallback, DiveMapCoordinateResolver.isUsable(fallback) {
            return fallback
        }
        return defaultCenter
    }

    nonisolated static func region(for center: DiveCoordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
            span: MKCoordinateSpan(
                latitudeDelta: pickerLatitudeDelta,
                longitudeDelta: pickerLongitudeDelta
            )
        )
    }

    nonisolated static func formattedLatitude(_ value: Double) -> String {
        String(format: "%.5f", value)
    }

    nonisolated static func formattedLongitude(_ value: Double) -> String {
        String(format: "%.5f", value)
    }

    nonisolated static func formattedTexts(for coordinate: DiveCoordinate) -> (latitude: String, longitude: String) {
        (
            formattedLatitude(coordinate.latitude),
            formattedLongitude(coordinate.longitude)
        )
    }
}
