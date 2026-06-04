import Foundation
#if canImport(GoogleMaps)
import GoogleMaps
import UIKit

/// One-time Google Maps SDK initialization during app launch so the first **Explore** map is less janky.
///
/// Warms **`GMSServices`**, the render pipeline, and a hidden **hybrid** **`GMSMapView`** (same stack as **Explore**).
/// Does **not** prefetch dive-site tiles — first visit to a new region may still load on demand.
@MainActor
enum GoogleMapsWarmup {
    private(set) static var didWarmUp = false

    static var shouldWarmUp: Bool {
        GoogleMapsBootstrap.shouldWarmUpAtLaunch
    }

    /// Safe to call repeatedly; runs at most once per process (skipped under UI tests / without Google key).
    static func warmUpIfNeeded() {
        guard shouldWarmUp, !didWarmUp else { return }

        GoogleMapsBootstrap.configureIfNeeded()
        guard GoogleMapsBootstrap.isConfigured else { return }
        didWarmUp = true

        let mapView = GoDiveMapPointOfInterestSuppression.makeGoogleMapView()
        mapView.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
        mapView.isUserInteractionEnabled = false
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
        mapView.mapType = .hybrid
        GoDiveMapPointOfInterestSuppression.applyToGoogleMaps(mapView)

        let region = DiveLocationMapPresentation.defaultRegion
        mapView.moveCamera(
            GMSCameraUpdate.setTarget(
                CLLocationCoordinate2D(
                    latitude: region.centerLatitude,
                    longitude: region.centerLongitude
                ),
                zoom: 2
            )
        )
        mapView.layoutIfNeeded()

        guard let window = keyWindow else { return }
        mapView.alpha = 0
        mapView.isAccessibilityElement = false
        window.addSubview(mapView)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            mapView.removeFromSuperview()
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
