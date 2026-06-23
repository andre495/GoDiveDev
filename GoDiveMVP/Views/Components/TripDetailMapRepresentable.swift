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
        context.coordinator.scheduleRegionApplyIfNeeded(
            on: mapView,
            pins: pins,
            fitLayout: fitLayout,
            animated: pinsChanged || layoutChanged
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var pins: [TripDetailMapPin] = []
        private var lastPinsSignature: String?
        private var lastFitLayoutSignature: String?
        private var lastAppliedRegionSignature: String?
        private var currentFitLayout: TripDetailMapFitLayout?
        private var selectedPinID: String?
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
            selectedPinID = nil

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
            currentFitLayout = fitLayout

            let layoutHeight = TripDetailMapPresentation.effectiveMapHeight(
                measuredBoundsHeight: mapView.bounds.height,
                fitLayout: fitLayout
            )
            guard layoutHeight > 1 else { return }

            let hasMeasuredBounds = TripDetailMapPresentation.hasMeasuredMapBounds(
                width: mapView.bounds.width,
                height: mapView.bounds.height
            )
            let boundsSignature = hasMeasuredBounds
                ? String(format: "%.0f|%.0f", mapView.bounds.width, mapView.bounds.height)
                : "provisional"
            let signature = "\(pins.map(\.id).sorted().joined(separator: "|"))|\(fitLayout.layoutSignature)|\(boundsSignature)"
            guard signature != lastAppliedRegionSignature else { return }
            lastAppliedRegionSignature = signature

            let applyLayout = TripDetailMapFitLayout(
                mapHeight: layoutHeight,
                topObstructionHeight: fitLayout.topObstructionHeight,
                panelOverlap: fitLayout.panelOverlap
            )
            applyRegion(
                on: mapView,
                pins: pins,
                fitLayout: applyLayout,
                hasMeasuredBounds: hasMeasuredBounds,
                animated: animated
            )
        }

        func applyRegion(
            on mapView: MKMapView,
            pins: [TripDetailMapPin],
            fitLayout: TripDetailMapFitLayout,
            hasMeasuredBounds: Bool,
            animated: Bool
        ) {
            isApplyingRegion = true
            defer { isApplyingRegion = false }

            if hasMeasuredBounds, let zoomRect = TripDetailMapPresentation.mkMapRect(for: pins) {
                let padding = TripDetailMapPresentation.uiMapFitEdgeInsets(for: fitLayout)
                let visibleRect = mapView.mapRectThatFits(zoomRect, edgePadding: padding)
                mapView.setVisibleMapRect(visibleRect, animated: animated)
            } else if let region = TripDetailMapPresentation.fittingRegion(for: pins) {
                mapView.setRegion(region.mkCoordinateRegion, animated: animated)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let tripAnnotation = annotation as? TripDetailMapAnnotation else { return nil }

            let identifier = Self.calloutPinReuseIdentifier
            let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            pinView.annotation = annotation
            applyCalloutPinPresentation(to: pinView, tripAnnotation: tripAnnotation)
            return pinView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if let fitLayout = currentFitLayout, !pins.isEmpty {
                scheduleRegionApplyIfNeeded(
                    on: mapView,
                    pins: pins,
                    fitLayout: fitLayout,
                    animated: false
                )
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let tripAnnotation = view.annotation as? TripDetailMapAnnotation else { return }

            TripDetailMapNavigationDebug.pinSelected(
                engine: .mapKit,
                pinID: tripAnnotation.pinID,
                kind: tripAnnotation.kind,
                siteID: tripAnnotation.siteID,
                title: tripAnnotation.siteDisplayName ?? tripAnnotation.pinID
            )

            guard tripAnnotation.siteID != nil else {
                TripDetailMapNavigationDebug.pinIgnoredMissingSiteID(
                    engine: .mapKit,
                    pinID: tripAnnotation.pinID,
                    kind: tripAnnotation.kind
                )
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            selectedPinID = tripAnnotation.pinID
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let tripAnnotation = view.annotation as? TripDetailMapAnnotation else { return }
            if selectedPinID == tripAnnotation.pinID {
                selectedPinID = nil
            }
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            calloutAccessoryControlTapped control: UIControl
        ) {
            guard let tripAnnotation = view.annotation as? TripDetailMapAnnotation,
                  let siteID = tripAnnotation.siteID else { return }

            onSiteSelected(siteID)
            mapView.deselectAnnotation(view.annotation, animated: true)
            selectedPinID = nil
        }

        private func applyCalloutPinPresentation(
            to pinView: MKAnnotationView,
            tripAnnotation: TripDetailMapAnnotation
        ) {
            pinView.image = ExploreCatalogMapSiteCallout.makeTripMapPinImage(kind: tripAnnotation.kind)
            let imageHeight = pinView.image?.size.height ?? 32
            pinView.centerOffset = CGPoint(x: 0, y: -imageHeight / 2)
            pinView.canShowCallout = true
            pinView.rightCalloutAccessoryView = nil
            pinView.detailCalloutAccessoryView = ExploreCatalogMapSiteCallout.makeMapKitCalloutAccessory(
                siteName: tripAnnotation.siteDisplayName ?? ""
            )
            pinView.accessibilityLabel = tripAnnotation.siteDisplayName
        }

        private static let calloutPinReuseIdentifier = "TripDetail.CalloutPin"
    }
}
#endif
