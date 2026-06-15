import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Read-only trip overview map — blue planned sites, red completed dives.
struct TripDetailMapRepresentable: UIViewRepresentable {
    let pins: [TripDetailMapPin]
    let fitLayout: TripDetailMapFitLayout
    var onSiteSelected: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSiteSelected: onSiteSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKHybridMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
        mapView.delegate = context.coordinator
        context.coordinator.syncAnnotations(on: mapView, pins: pins)
        context.coordinator.scheduleRegionApplyIfNeeded(
            on: mapView,
            pins: pins,
            fitLayout: fitLayout,
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let pinsChanged = context.coordinator.syncAnnotations(on: mapView, pins: pins)
        let layoutChanged = context.coordinator.syncFitLayout(fitLayout)
        if pinsChanged || layoutChanged {
            context.coordinator.scheduleRegionApplyIfNeeded(
                on: mapView,
                pins: pins,
                fitLayout: fitLayout,
                animated: pinsChanged
            )
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var pins: [TripDetailMapPin] = []
        private var lastPinsSignature: String?
        private var lastFitLayoutSignature: String?
        private var lastAppliedRegionSignature: String?
        private var labeledPinIDs: Set<String> = []
        private var isApplyingRegion = false

        init(onSiteSelected: @escaping (UUID) -> Void) {
            self.onSiteSelected = onSiteSelected
        }

        @discardableResult
        func syncAnnotations(on mapView: MKMapView, pins: [TripDetailMapPin]) -> Bool {
            self.pins = pins
            let signature = pins.map(\.id).sorted().joined(separator: "|")
            let pinsChanged = signature != lastPinsSignature
            guard pinsChanged else { return false }
            lastPinsSignature = signature
            labeledPinIDs = []

            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(pins.map(TripDetailMapAnnotation.init(pin:)))
            return true
        }

        @discardableResult
        func syncFitLayout(_ fitLayout: TripDetailMapFitLayout) -> Bool {
            let signature = fitLayout.layoutSignature
            guard signature != lastFitLayoutSignature else { return false }
            lastFitLayoutSignature = signature
            return true
        }

        func scheduleRegionApplyIfNeeded(
            on mapView: MKMapView,
            pins: [TripDetailMapPin],
            fitLayout: TripDetailMapFitLayout,
            animated: Bool
        ) {
            guard !pins.isEmpty else { return }
            guard mapView.bounds.width > 1, mapView.bounds.height > 1 else { return }

            let signature = "\(pins.map(\.id).sorted().joined(separator: "|"))|\(fitLayout.layoutSignature)"
            guard signature != lastAppliedRegionSignature else { return }
            lastAppliedRegionSignature = signature

            let applyLayout = TripDetailMapFitLayout(
                mapHeight: mapView.bounds.height,
                topObstructionHeight: fitLayout.topObstructionHeight,
                panelOverlap: fitLayout.panelOverlap
            )
            applyRegion(on: mapView, pins: pins, fitLayout: applyLayout, animated: animated)
            refreshLabelVisibility(on: mapView)
        }

        func applyRegion(
            on mapView: MKMapView,
            pins: [TripDetailMapPin],
            fitLayout: TripDetailMapFitLayout,
            animated: Bool
        ) {
            let annotations = mapView.annotations.compactMap { $0 as? TripDetailMapAnnotation }
            guard !annotations.isEmpty else { return }

            var zoomRect = MKMapRect.null
            for annotation in annotations {
                let point = MKMapPoint(annotation.coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                zoomRect = zoomRect.union(pointRect)
            }

            isApplyingRegion = true
            let padding = TripDetailMapPresentation.uiMapFitEdgeInsets(for: fitLayout)
            let visibleRect = mapView.mapRectThatFits(zoomRect, edgePadding: padding)
            mapView.setVisibleMapRect(visibleRect, animated: animated)
            isApplyingRegion = false
        }

        func refreshLabelVisibility(on mapView: MKMapView) {
            guard !pins.isEmpty else { return }

            let span = mapView.region.span.latitudeDelta
            let center = DiveCoordinate(
                latitude: mapView.region.center.latitude,
                longitude: mapView.region.center.longitude
            )
            let updatedLabeledPinIDs = ExploreCatalogMapLabelVisibility.labeledTripPinIDs(
                pins: pins,
                visibleLatitudeSpan: span,
                mapCenter: center
            )
            guard updatedLabeledPinIDs != labeledPinIDs else { return }
            labeledPinIDs = updatedLabeledPinIDs

            for annotation in mapView.annotations {
                guard let tripAnnotation = annotation as? TripDetailMapAnnotation,
                      let markerView = mapView.view(for: annotation) as? MKMarkerAnnotationView
                else { continue }
                markerView.titleVisibility = labeledPinIDs.contains(tripAnnotation.pinID) ? .visible : .hidden
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let tripAnnotation = annotation as? TripDetailMapAnnotation else { return nil }

            let identifier = Self.markerReuseIdentifier
            let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            markerView.annotation = annotation
            markerView.markerTintColor = tripAnnotation.kind == .planned ? .systemBlue : .systemRed
            markerView.titleVisibility = labeledPinIDs.contains(tripAnnotation.pinID) ? .visible : .hidden
            markerView.subtitleVisibility = .hidden
            markerView.canShowCallout = false
            markerView.displayPriority = .defaultHigh
            markerView.accessibilityLabel = tripAnnotation.title
            return markerView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isApplyingRegion else { return }
            refreshLabelVisibility(on: mapView)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let tripAnnotation = view.annotation as? TripDetailMapAnnotation else { return }

            TripDetailMapNavigationDebug.pinSelected(
                engine: .mapKit,
                pinID: tripAnnotation.pinID,
                kind: tripAnnotation.kind,
                siteID: tripAnnotation.siteID,
                title: tripAnnotation.title ?? tripAnnotation.pinID
            )

            guard let siteID = tripAnnotation.siteID else {
                TripDetailMapNavigationDebug.pinIgnoredMissingSiteID(
                    engine: .mapKit,
                    pinID: tripAnnotation.pinID,
                    kind: tripAnnotation.kind
                )
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            onSiteSelected(siteID)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        private static let markerReuseIdentifier = "TripDetail.StandardMarker"
    }
}
#endif
