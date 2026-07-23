import CoreGraphics
import CoreLocation

/// Map camera / marker rules for the dive overview map (testable without SwiftUI).
///
/// Pure geometry — **`nonisolated`** so tank hero layout and tests stay off the main actor (Swift 6).
enum DiveLocationMapPresentation: Sendable {
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

    /// **Minimized** sheet — wider context above the summary strip (pan/zoom enabled).
    nonisolated static let minimizedCameraDistanceMeters: CLLocationDistance = 6_200
    /// **Medium** (~half screen sheet) — tighter site framing. Also used for **large** (map hidden by sheet).
    nonisolated static let mediumCameraDistanceMeters: CLLocationDistance = 1_200

    nonisolated static func cameraDistanceMeters(for detent: DiveActivityOverviewDetent) -> CLLocationDistance {
        switch detent.mapCameraDetent {
        case .minimized: minimizedCameraDistanceMeters
        case .large: mediumCameraDistanceMeters
        }
    }

    /// Zoom interpolates with overview panel height — wide at **minimized**, tight at **large**.
    nonisolated static func cameraDistanceMeters(
        sheetHeightFraction: CGFloat,
        largeRestingFraction: CGFloat
    ) -> CLLocationDistance {
        let progress = DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(
            heightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
        let wide = minimizedCameraDistanceMeters
        let tight = mediumCameraDistanceMeters
        return wide + (tight - wide) * progress
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

    /// On-map pin subtitle (max **3** decimal places).
    nonisolated static func coordinateLabel(for coordinate: DiveCoordinate) -> String {
        String(format: "%.3f°, %.3f°", coordinate.latitude, coordinate.longitude)
    }

    /// Coordinate string for **`MKMarkerAnnotationView`** title (locale decimal separators, **3** fractional digits).
    nonisolated static func mapMarkerCoordinateTitle(
        for coordinate: DiveCoordinate,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false

        func formattedDegrees(_ value: Double) -> String {
            guard let number = formatter.string(from: NSNumber(value: value)) else {
                return String(format: "%.3f", locale: locale, value)
            }
            return "\(number)°"
        }

        return "\(formattedDegrees(coordinate.latitude)), \(formattedDegrees(coordinate.longitude))"
    }

    /// Stable **`View.id`** so MapKit remounts when the dive or resolved coordinate changes.
    nonisolated static func mapViewIdentity(activityID: UUID, coordinate: DiveCoordinate?) -> String {
        let coordinatePart: String
        if let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) {
            coordinatePart = "\(coordinate.latitude),\(coordinate.longitude)"
        } else {
            coordinatePart = "none"
        }
        return "\(activityID.uuidString)-\(coordinatePart)"
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

    /// Empirical tuning — **`MapCamera`** altitude does not match region **`latitudeDelta`** linearly.
    nonisolated static func latitudeShiftTuning(for detent: DiveActivityOverviewDetent) -> CGFloat {
        switch detent.mapCameraDetent {
        case .minimized: 0.52
        case .large: 0.38
        }
    }

    nonisolated static func latitudeShiftTuning(
        sheetHeightFraction: CGFloat,
        largeRestingFraction: CGFloat
    ) -> CGFloat {
        let progress = DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(
            heightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
        let minimizedTuning: CGFloat = 0.52
        let largeTuning: CGFloat = 0.38
        return minimizedTuning + (largeTuning - minimizedTuning) * progress
    }

    /// Sheet coverage as a fraction of **`layoutHeight`** (panel + home indicator), for map framing.
    nonisolated static func sheetHeightFraction(
        layoutHeight: CGFloat,
        bottomContentMargin: CGFloat
    ) -> CGFloat {
        min(max(bottomContentMargin / max(layoutHeight, 1), 0), 0.92)
    }

    /// Shifts the camera center so the pin at **`coordinate`** sits at **`targetPinScreenYFraction`**.
    nonisolated static func adjustedMapCenter(
        for coordinate: DiveCoordinate,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        sheetHeightFraction: CGFloat,
        largeRestingFraction: CGFloat
    ) -> CLLocationCoordinate2D {
        let h = max(layoutHeight, 1)
        let sheetFraction = Self.sheetHeightFraction(
            layoutHeight: h,
            bottomContentMargin: bottomContentMargin
        )
        let targetY = targetPinScreenYFraction(
            layoutHeight: h,
            topObstructionHeight: topObstructionHeight,
            sheetHeightFraction: sheetFraction
        )
        let offsetFromCenter = 0.5 - targetY
        guard abs(offsetFromCenter) > 0.0005 else {
            return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        let distance = cameraDistanceMeters(
            sheetHeightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
        let distanceScale = CGFloat(distance / referenceCameraDistanceMeters)
        let latitudeShift = offsetFromCenter
            * diveSiteLatitudeDelta
            * distanceScale
            * latitudeShiftTuning(
                sheetHeightFraction: sheetHeightFraction,
                largeRestingFraction: largeRestingFraction
            )
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude - latitudeShift,
            longitude: coordinate.longitude
        )
    }

    /// Detent-based pin shift — prefer **`sheetHeightFraction`** while the grabber moves.
    nonisolated static func adjustedMapCenter(
        for coordinate: DiveCoordinate,
        layoutHeight: CGFloat,
        topObstructionHeight: CGFloat,
        bottomContentMargin: CGFloat,
        mapCameraDetent: DiveActivityOverviewDetent,
        largeRestingFraction: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
    ) -> CLLocationCoordinate2D {
        let sheetHeightFraction: CGFloat
        switch mapCameraDetent {
        case .minimized:
            sheetHeightFraction = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        case .large:
            sheetHeightFraction = largeRestingFraction
        }
        return adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            sheetHeightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
    }
}
