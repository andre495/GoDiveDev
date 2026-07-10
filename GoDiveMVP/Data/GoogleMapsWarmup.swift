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
    private static var hasScheduledWarmUp = false

    static var shouldWarmUp: Bool {
        GoogleMapsBootstrap.shouldWarmUpAtLaunch
    }

    /// Safe to call repeatedly; schedules at most one warm-up per process (skipped under UI tests / without Google key).
    /// Pass **`includeHiddenMapView: false`** before **`ContentView`** shell prewarm so Explore’s real map is the only **`GMSMapView`**.
    static func warmUpIfNeeded(includeHiddenMapView: Bool = true) {
        guard shouldWarmUp, !didWarmUp, !hasScheduledWarmUp else { return }
        hasScheduledWarmUp = true
        Task { @MainActor in
            await performWarmUpOnce(includeHiddenMapView: includeHiddenMapView)
        }
    }

    private static func performWarmUpOnce(includeHiddenMapView: Bool) async {
        defer { hasScheduledWarmUp = false }
        guard shouldWarmUp, !didWarmUp else { return }

        await Task.yield()
        GoogleMapsBootstrap.configureIfNeeded()
        guard GoogleMapsBootstrap.isConfigured else { return }
        didWarmUp = true
        guard includeHiddenMapView else { return }

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

        guard let window = keyWindow else { return }
        mapView.alpha = 0
        mapView.isAccessibilityElement = false
        window.addSubview(mapView)
        await Task.yield()
        mapView.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        mapView.removeFromSuperview()
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
