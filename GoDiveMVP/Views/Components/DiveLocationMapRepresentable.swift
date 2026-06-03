import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// UIKit **`MKMapView`** dive map — system **`MKMarkerAnnotationView`** with native coordinate title (site name on sheet header).
struct DiveLocationMapRepresentable: UIViewRepresentable {
    let coordinate: DiveCoordinate?
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    let cameraLayoutDetent: DiveActivityOverviewDetent
    var isUserInteractionEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKImageryMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncDiveAnnotation(on: mapView)
        applyUserInteraction(on: mapView)

        guard layoutHeight > 1 else { return }

        let layoutContext = mapLayoutContext
        let previous = context.coordinator.lastAppliedLayoutContext
        let animateDetentChange = previous != nil
            && previous?.cameraLayoutDetent != layoutContext.cameraLayoutDetent
        guard layoutContext != previous else { return }

        context.coordinator.applyCamera(on: mapView, animated: animateDetentChange)
        context.coordinator.lastAppliedLayoutContext = layoutContext
    }

    private var mapLayoutContext: DiveMapCameraLayoutContext {
        DiveMapCameraLayoutContext(
            coordinateIdentity: coordinateIdentity,
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            cameraLayoutDetent: cameraLayoutDetent
        )
    }

    private var coordinateIdentity: String {
        guard let coordinate else { return "none" }
        return "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func applyUserInteraction(on mapView: MKMapView) {
        mapView.isScrollEnabled = isUserInteractionEnabled
        mapView.isZoomEnabled = isUserInteractionEnabled
        mapView.isPitchEnabled = false
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DiveLocationMapRepresentable?
        var lastAppliedLayoutContext: DiveMapCameraLayoutContext?
        private var diveAnnotation: MKPointAnnotation?
        private var lastAnnotationKey: String?

        func syncDiveAnnotation(on mapView: MKMapView) {
            guard let parent else { return }

            guard parent.coordinateIdentity != lastAnnotationKey else { return }
            lastAnnotationKey = parent.coordinateIdentity

            if let existing = diveAnnotation {
                mapView.removeAnnotation(existing)
                diveAnnotation = nil
            }

            guard let coordinate = parent.coordinate,
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { return }

            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            annotation.title = DiveLocationMapPresentation.mapMarkerCoordinateTitle(for: coordinate)
            diveAnnotation = annotation
            mapView.addAnnotation(annotation)
        }

        func applyCamera(on mapView: MKMapView, animated: Bool) {
            guard let parent else { return }

            let camera = Self.makeCamera(parent: parent)
            if animated {
                mapView.setCamera(camera, animated: true)
            } else {
                mapView.setCamera(camera, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = Self.standardMarkerReuseIdentifier
            let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            markerView.annotation = annotation
            markerView.markerTintColor = .systemRed
            markerView.titleVisibility = .visible
            markerView.subtitleVisibility = .hidden
            markerView.canShowCallout = false
            if let coordinate = parent?.coordinate,
               DiveMapCoordinateResolver.isUsable(coordinate) {
                markerView.accessibilityLabel = "Dive site, \(DiveLocationMapPresentation.mapMarkerCoordinateTitle(for: coordinate))"
            }
            return markerView
        }

        private static let standardMarkerReuseIdentifier = "DiveLocation.StandardMarker"

        private static func makeCamera(parent: DiveLocationMapRepresentable) -> MKMapCamera {
            guard let coordinate = parent.coordinate,
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else {
                let region = DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion
                return MKMapCamera(
                    lookingAtCenter: region.center,
                    fromDistance: 8_000_000,
                    pitch: 0,
                    heading: 0
                )
            }

            let distance = DiveLocationMapPresentation.cameraDistanceMeters(for: parent.cameraLayoutDetent)
            let center = DiveLocationMapPresentation.adjustedMapCenter(
                for: coordinate,
                layoutHeight: parent.layoutHeight,
                topObstructionHeight: parent.topObstructionHeight,
                bottomContentMargin: parent.bottomContentMargin,
                mapCameraDetent: parent.cameraLayoutDetent
            )
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude
                ),
                fromDistance: distance,
                pitch: 0,
                heading: 0
            )
        }

    }
}
#endif
