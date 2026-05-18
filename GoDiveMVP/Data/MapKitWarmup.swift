import MapKit
import UIKit

/// One-time MapKit initialization during app launch so the first visible map is less janky.
///
/// Warms the MapKit framework, render pipeline, and a default world region. Does **not** prefetch
/// dive-specific tiles — the first pin at a new coordinate may still load tiles on demand.
@MainActor
enum MapKitWarmup {
    private(set) static var didWarmUp = false

    static var shouldWarmUp: Bool {
        !GoDiveUITestConfiguration.isActive
    }

    /// Safe to call repeatedly; runs at most once per process (skipped under UI tests).
    static func warmUpIfNeeded() {
        guard shouldWarmUp, !didWarmUp else { return }
        didWarmUp = true

        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        mapView.isUserInteractionEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.region = DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion
        mapView.layoutIfNeeded()

        guard let window = keyWindow else { return }
        mapView.alpha = 0
        mapView.isAccessibilityElement = false
        window.addSubview(mapView)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
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
