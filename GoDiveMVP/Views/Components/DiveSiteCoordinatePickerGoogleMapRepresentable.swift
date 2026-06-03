import GoogleMaps
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Pannable mini map for **`DiveSiteAddSheet`** — hybrid **`GMSMapView`**; fixed overlay pin marks the site coordinate.
struct DiveSiteCoordinatePickerGoogleMapRepresentable: UIViewRepresentable {
    let centerCoordinate: DiveCoordinate
    var onCenterCoordinateChanged: (DiveCoordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCenterCoordinateChanged: onCenterCoordinateChanged)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GoDiveMapPointOfInterestSuppression.makeGoogleMapView()
        mapView.mapType = .hybrid
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
        GoDiveMapPointOfInterestSuppression.applyToGoogleMaps(mapView)
        mapView.settings.rotateGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator
        context.coordinator.scheduleInitialCamera(center: centerCoordinate)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onCenterCoordinateChanged = onCenterCoordinateChanged
        context.coordinator.applyScheduledInitialCamera(on: mapView)
        guard context.coordinator.shouldApplyExternalCenter(centerCoordinate) else { return }
        context.coordinator.applyCamera(on: mapView, center: centerCoordinate, animated: true)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onCenterCoordinateChanged: (DiveCoordinate) -> Void
        private var lastReportedCenter: DiveCoordinate?
        private var lastAppliedExternalCenter: DiveCoordinate?
        private var isApplyingProgrammaticCamera = false
        private var scheduledInitialCenter: DiveCoordinate?
        private var didApplyScheduledInitialCamera = false

        init(onCenterCoordinateChanged: @escaping (DiveCoordinate) -> Void) {
            self.onCenterCoordinateChanged = onCenterCoordinateChanged
        }

        func scheduleInitialCamera(center: DiveCoordinate) {
            scheduledInitialCenter = center
            didApplyScheduledInitialCamera = false
        }

        func applyScheduledInitialCamera(on mapView: GMSMapView) {
            guard !didApplyScheduledInitialCamera else { return }
            guard let center = scheduledInitialCenter else { return }
            guard mapView.bounds.width > 1, mapView.bounds.height > 1 else { return }
            didApplyScheduledInitialCamera = true
            applyCamera(on: mapView, center: center, animated: false)
            lastReportedCenter = center
        }

        func shouldApplyExternalCenter(_ center: DiveCoordinate) -> Bool {
            guard lastAppliedExternalCenter != center else { return false }
            guard let lastReportedCenter else { return true }
            return !coordinatesApproximatelyEqual(lastReportedCenter, center)
        }

        func applyCamera(on mapView: GMSMapView, center: DiveCoordinate, animated: Bool) {
            isApplyingProgrammaticCamera = true
            lastAppliedExternalCenter = center
            let position = GMSCameraPosition(
                target: CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude
                ),
                zoom: DiveSiteCoordinatePickerPresentation.approximateZoomLevel(for: center)
            )
            if animated {
                mapView.animate(to: position)
            } else {
                mapView.camera = position
            }
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            applyScheduledInitialCamera(on: mapView)
            guard !isApplyingProgrammaticCamera else { return }
            reportCenterIfNeeded(from: mapView)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            applyScheduledInitialCamera(on: mapView)
            if isApplyingProgrammaticCamera {
                isApplyingProgrammaticCamera = false
                if let applied = lastAppliedExternalCenter {
                    lastReportedCenter = applied
                }
                return
            }
            reportCenterIfNeeded(from: mapView)
        }

        private func reportCenterIfNeeded(from mapView: GMSMapView) {
            guard mapView.bounds.width > 1, mapView.bounds.height > 1 else { return }

            let point = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
            let location = mapView.projection.coordinate(for: point)
            let candidate = DiveCoordinate(latitude: location.latitude, longitude: location.longitude)
            guard DiveMapCoordinateResolver.isUsable(candidate) else { return }
            guard !coordinatesApproximatelyEqual(lastReportedCenter, candidate) else { return }

            lastReportedCenter = candidate
            lastAppliedExternalCenter = candidate
            onCenterCoordinateChanged(candidate)
        }

        private func coordinatesApproximatelyEqual(_ lhs: DiveCoordinate?, _ rhs: DiveCoordinate) -> Bool {
            guard let lhs else { return false }
            return abs(lhs.latitude - rhs.latitude) < 0.000_01
                && abs(lhs.longitude - rhs.longitude) < 0.000_01
        }
    }
}
#endif
