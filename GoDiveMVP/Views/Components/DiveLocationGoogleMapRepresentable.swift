import GoogleMaps
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// **Dive overview** map backed by **`GMSMapView`** — hybrid tiles, entry coordinate label on the pin.
struct DiveLocationGoogleMapRepresentable: UIViewRepresentable {
    let coordinate: DiveCoordinate?
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    let sheetHeightFraction: CGFloat
    let largeRestingFraction: CGFloat
    var isUserInteractionEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        context.coordinator.parent = self
        applyViewportPadding(on: mapView)
        context.coordinator.syncMarker(on: mapView)
        applyUserInteraction(on: mapView)
        context.coordinator.applyCamera(on: mapView, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        applyViewportPadding(on: mapView)
        context.coordinator.syncMarker(on: mapView)
        applyUserInteraction(on: mapView)

        guard layoutHeight > 1 else { return }

        let layoutContext = mapLayoutContext
        let previous = context.coordinator.lastAppliedLayoutContext
        let animateSnap = previous.map {
            Self.restingDetentSnap(for: $0) != Self.restingDetentSnap(for: layoutContext)
        } ?? false
        guard layoutContext != previous else { return }

        context.coordinator.applyCamera(on: mapView, animated: animateSnap)
        context.coordinator.lastAppliedLayoutContext = layoutContext
    }

    private static func restingDetentSnap(for context: DiveMapCameraLayoutContext) -> DiveActivityOverviewDetent {
        DiveActivityOverviewDetent.nearest(
            toHeightFraction: context.sheetHeightFraction,
            largeRestingFraction: context.largeRestingFraction
        )
    }

    private var mapLayoutContext: DiveMapCameraLayoutContext {
        DiveMapCameraLayoutContext(
            coordinateIdentity: coordinateIdentity,
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            sheetHeightFraction: sheetHeightFraction,
            largeRestingFraction: largeRestingFraction
        )
    }

    private var coordinateIdentity: String {
        guard let coordinate else { return "none" }
        return "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func applyUserInteraction(on mapView: GMSMapView) {
        mapView.settings.scrollGestures = isUserInteractionEnabled
        mapView.settings.zoomGestures = isUserInteractionEnabled
        mapView.settings.tiltGestures = false
    }

    /// Insets the legal viewport so the dive pin centers in the map band above the sheet (matches **`targetPinScreenYFraction`**).
    private func applyViewportPadding(on mapView: GMSMapView) {
        mapView.padding = UIEdgeInsets(
            top: max(topObstructionHeight, 0),
            left: 0,
            bottom: max(bottomContentMargin, 0),
            right: 0
        )
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: DiveLocationGoogleMapRepresentable?
        var lastAppliedLayoutContext: DiveMapCameraLayoutContext?
        private var diveMarker: GMSMarker?
        private var lastMarkerKey: String?

        func syncMarker(on mapView: GMSMapView) {
            guard let parent else { return }

            guard parent.coordinateIdentity != lastMarkerKey else { return }
            lastMarkerKey = parent.coordinateIdentity

            diveMarker?.map = nil
            diveMarker = nil

            guard let coordinate = parent.coordinate,
                  DiveMapCoordinateResolver.isUsable(coordinate)
            else { return }

            let label = DiveLocationMapPresentation.mapMarkerCoordinateTitle(for: coordinate)
            let labeledPin = ExploreCatalogGoogleMapMarkerImageFactory.makeLabeledPinAsset(
                labelText: label,
                tint: .systemRed,
                scale: mapView.traitCollection.displayScale,
                maxLabelWidth: 168
            )
            let marker = GMSMarker(
                position: CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
            marker.title = label
            marker.icon = labeledPin.image
            marker.groundAnchor = labeledPin.groundAnchor
            marker.accessibilityLabel = "Dive entry coordinate, \(label)"
            marker.map = mapView
            diveMarker = marker
        }

        func applyCamera(on mapView: GMSMapView, animated: Bool) {
            guard let parent else { return }

            let spec = DiveLocationMapGoogleCameraPresentation.cameraSpec(
                coordinate: parent.coordinate,
                layoutHeight: parent.layoutHeight,
                topObstructionHeight: parent.topObstructionHeight,
                bottomContentMargin: parent.bottomContentMargin,
                sheetHeightFraction: parent.sheetHeightFraction,
                largeRestingFraction: parent.largeRestingFraction
            )
            let position = GMSCameraPosition(
                target: CLLocationCoordinate2D(
                    latitude: spec.centerLatitude,
                    longitude: spec.centerLongitude
                ),
                zoom: spec.zoomLevel
            )
            if animated {
                mapView.animate(to: position)
            } else {
                mapView.camera = position
            }
        }
    }
}
#endif
