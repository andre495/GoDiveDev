import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Pannable mini map; the fixed center crosshair marks the site coordinate.
struct DiveSiteCoordinatePickerMapRepresentable: UIViewRepresentable {
    let centerCoordinate: DiveCoordinate
    var onCenterCoordinateChanged: (DiveCoordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCenterCoordinateChanged: onCenterCoordinateChanged)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKImageryMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
        mapView.delegate = context.coordinator
        context.coordinator.scheduleInitialRegion(center: centerCoordinate)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onCenterCoordinateChanged = onCenterCoordinateChanged
        context.coordinator.applyScheduledInitialRegion(on: mapView)
        guard context.coordinator.shouldApplyExternalCenter(centerCoordinate) else { return }
        context.coordinator.applyRegion(on: mapView, center: centerCoordinate, animated: true)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCenterCoordinateChanged: (DiveCoordinate) -> Void
        private var lastReportedCenter: DiveCoordinate?
        private var lastAppliedExternalCenter: DiveCoordinate?
        private var isApplyingProgrammaticRegion = false
        private var scheduledInitialCenter: DiveCoordinate?
        private var didApplyScheduledInitialRegion = false

        init(onCenterCoordinateChanged: @escaping (DiveCoordinate) -> Void) {
            self.onCenterCoordinateChanged = onCenterCoordinateChanged
        }

        func scheduleInitialRegion(center: DiveCoordinate) {
            scheduledInitialCenter = center
            didApplyScheduledInitialRegion = false
        }

        func applyScheduledInitialRegion(on mapView: MKMapView) {
            guard !didApplyScheduledInitialRegion else { return }
            guard let center = scheduledInitialCenter else { return }
            guard mapView.bounds.width > 1, mapView.bounds.height > 1 else { return }
            didApplyScheduledInitialRegion = true
            applyRegion(on: mapView, center: center, animated: false)
            lastReportedCenter = center
        }

        func shouldApplyExternalCenter(_ center: DiveCoordinate) -> Bool {
            guard lastAppliedExternalCenter != center else { return false }
            guard let lastReportedCenter else { return true }
            return !coordinatesApproximatelyEqual(lastReportedCenter, center)
        }

        func applyRegion(on mapView: MKMapView, center: DiveCoordinate, animated: Bool) {
            isApplyingProgrammaticRegion = true
            lastAppliedExternalCenter = center
            let region = DiveSiteCoordinatePickerPresentation.region(for: center)
            mapView.setRegion(region, animated: animated)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            applyScheduledInitialRegion(on: mapView)

            if isApplyingProgrammaticRegion {
                isApplyingProgrammaticRegion = false
                if let applied = lastAppliedExternalCenter {
                    lastReportedCenter = applied
                }
                return
            }
            guard mapView.bounds.width > 1, mapView.bounds.height > 1 else { return }

            let point = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
            let location = mapView.convert(point, toCoordinateFrom: mapView)
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
