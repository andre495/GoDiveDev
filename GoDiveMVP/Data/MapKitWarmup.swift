import MapKit
import UIKit

/// One-time MapKit initialization so the first visible map is less janky (Explore tab or late launch fallback).
///
/// Warms the MapKit framework, render pipeline, and a default world region. Does **not** prefetch
/// dive-specific tiles — the first pin at a new coordinate may still load tiles on demand.
///
/// Scheduling mirrors **`GoogleMapsWarmup`**: never create / insert **`MKMapView`** synchronously
/// on the Explore tab-select path (that blocked the first interactive frame).
@MainActor
enum MapKitWarmup {
    private(set) static var didWarmUp = false
    private static var hasScheduledWarmUp = false

    static var shouldWarmUp: Bool {
        !GoDiveUITestConfiguration.isActive
    }

    /// Safe to call repeatedly; schedules at most one warm-up per process (skipped under UI tests).
    static func warmUpIfNeeded() {
        guard shouldWarmUp, !didWarmUp, !hasScheduledWarmUp else { return }
        hasScheduledWarmUp = true
        Task { @MainActor in
            await performWarmUpOnce()
        }
    }

    private static func performWarmUpOnce() async {
        defer { hasScheduledWarmUp = false }
        guard shouldWarmUp, !didWarmUp else { return }

        await Task.yield()
        didWarmUp = true

        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        mapView.isUserInteractionEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.region = DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion

        guard let window = keyWindow else { return }
        mapView.alpha = 0
        mapView.isAccessibilityElement = false
        window.addSubview(mapView)
        await Task.yield()
        mapView.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(120))
        mapView.removeFromSuperview()
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    #if DEBUG
    static func resetForTesting() {
        didWarmUp = false
        hasScheduledWarmUp = false
    }
    #endif
}
