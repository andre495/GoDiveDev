import CoreGraphics
import CoreLocation

/// Map camera / marker rules for the dive overview map (testable without SwiftUI).
///
/// Pure geometry — **`nonisolated`** so tank hero layout and tests stay off the main actor (Swift 6).
enum DiveLocationMapPresentation: Sendable {
    nonisolated static let defaultMarkerTitle = "Dive site"

    /// Wide world view when a dive has no stored coordinates.
    nonisolated static let defaultRegion = DiveLocationMapRegionSpec(
        centerLatitude: 20,
        centerLongitude: 0,
        latitudeDelta: 120,
        longitudeDelta: 120
    )

    /// Baseline span for latitude shift math at **`referenceCameraDistanceMeters`**.
    nonisolated static let diveSiteLatitudeDelta = 0.05
    nonisolated static let diveSiteLongitudeDelta = 0.05

    /// Legacy default; prefer **`cameraDistanceMeters(for:)`** per sheet detent.
    nonisolated static let diveSiteCameraDistanceMeters: CLLocationDistance = 4_500

    /// Reference altitude for **`diveSiteLatitudeDelta`** scaling.
    nonisolated static let referenceCameraDistanceMeters: CLLocationDistance = 4_500

    /// **Minimized** sheet — tight zoom above the summary strip.
    nonisolated static let minimizedCameraDistanceMeters: CLLocationDistance = 1_200
    /// **Medium** (~half screen sheet) — slightly wider than legacy default. Also used for **large** (map hidden by sheet).
    nonisolated static let mediumCameraDistanceMeters: CLLocationDistance = 6_200

    nonisolated static func cameraDistanceMeters(for detent: DiveActivityOverviewDetent) -> CLLocationDistance {
        switch detent.mapCameraDetent {
        case .minimized: minimizedCameraDistanceMeters
        case .medium, .large: mediumCameraDistanceMeters
        }
    }

    nonisolated static func regionSpec(for coordinate: DiveCoordinate?) -> DiveLocationMapRegionSpec {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else { return defaultRegion }
        return DiveLocationMapRegionSpec(
            centerLatitude: coordinate.latitude,
            centerLongitude: coordinate.longitude,
            latitudeDelta: diveSiteLatitudeDelta,
            longitudeDelta: diveSiteLongitudeDelta
        )
    }

    nonisolated static func showsDiveMarker(for coordinate: DiveCoordinate?) -> Bool {
        DiveMapCoordinateResolver.isUsable(coordinate)
    }

    nonisolated static func markerTitle(siteName: String?, fallback: String) -> String {
        let trimmed = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Pin Y on the full-bleed map (fraction from top) — midpoint of the band between top chrome and the **sheet top edge**.
    ///
    /// Uses **`sheetHeightFraction`** (detent ratio only), not obstruction height including the home indicator,
    /// so the target sits in the map area the user actually sees above the sheet.
    nonisolated static func targetPinScreenYFraction(
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        sheetHeightFraction: CGFloat
    ) -> CGFloat {
        let h = max(layoutHeight, 1)
        let top = min(max(topObstructionHeight / h, 0), 0.9)
        let sheet = min(max(sheetHeightFraction, 0), 0.92)
        let visible = max(0, 1 - top - sheet)
        return top + visible / 2
    }

    /// Scales latitude offset — **`MapCamera`** distance does not match region **`latitudeDelta`** linearly; medium was overshooting.
    nonisolated static func latitudeShiftMultiplier(for detent: DiveActivityOverviewDetent) -> CGFloat {
        switch detent.mapCameraDetent {
        case .minimized: 1.0
        case .medium, .large: 0.52
        }
    }

    /// Shifts the camera center so the pin at **`coordinate`** sits in the visible band above the sheet.
    nonisolated static func adjustedMapCenter(
        for coordinate: DiveCoordinate,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        sheetHeightFraction: CGFloat,
        mapCameraDetent: DiveActivityOverviewDetent
    ) -> CLLocationCoordinate2D {
        let h = max(layoutHeight, 1)
        let topFraction = min(max(topObstructionHeight / h, 0), 0.9)
        let sheetFraction = min(max(sheetHeightFraction, 0), 0.92)

        // Midpoint of visible strip: shift camera south so the pin reads higher on screen.
        let halfBandShift = max(0, (sheetFraction - topFraction) / 2)
        guard halfBandShift > 0.001 else {
            return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        let shift = halfBandShift
            * diveSiteLatitudeDelta
            * latitudeShiftMultiplier(for: mapCameraDetent)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude - shift,
            longitude: coordinate.longitude
        )
    }
}
