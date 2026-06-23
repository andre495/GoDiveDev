import GoogleMaps
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct TripDetailGoogleMapRepresentable: UIViewRepresentable {
    let pins: [TripDetailMapPin]
    let fitLayout: TripDetailMapFitLayout
    var onSiteSelected: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSiteSelected: onSiteSelected)
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
        context.coordinator.syncMarkers(on: mapView, pins: pins)
        context.coordinator.scheduleRegionApplyIfNeeded(
            on: mapView,
            pins: pins,
            fitLayout: fitLayout,
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let pinsChanged = context.coordinator.syncMarkers(on: mapView, pins: pins)
        let layoutChanged = context.coordinator.syncFitLayout(fitLayout)
        context.coordinator.scheduleRegionApplyIfNeeded(
            on: mapView,
            pins: pins,
            fitLayout: fitLayout,
            animated: pinsChanged || layoutChanged
        )
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var pins: [TripDetailMapPin] = []
        private var markersByPinID: [String: GMSMarker] = [:]
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
        func syncMarkers(on mapView: GMSMapView, pins: [TripDetailMapPin]) -> Bool {
            self.pins = pins
            let signature = pins.map(\.id).sorted().joined(separator: "|")
            let pinsChanged = signature != lastPinsSignature
            guard pinsChanged else { return false }
            lastPinsSignature = signature
            selectedPinID = nil
            mapView.selectedMarker = nil

            for marker in markersByPinID.values {
                marker.map = nil
            }
            markersByPinID.removeAll()

            for pin in pins {
                let tint = Self.markerTint(for: pin.kind)
                let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset(tint: tint)
                let marker = GMSMarker(
                    position: CLLocationCoordinate2D(
                        latitude: pin.coordinate.latitude,
                        longitude: pin.coordinate.longitude
                    )
                )
                marker.title = ExploreCatalogMapMarkerPresentation.displayTitle(for: pin.title)
                marker.icon = pinOnly.image
                marker.groundAnchor = pinOnly.groundAnchor
                marker.userData = pin.siteID
                marker.accessibilityLabel = marker.title
                marker.tracksInfoWindowChanges = true
                marker.map = mapView
                markersByPinID[pin.id] = marker
            }

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
            on mapView: GMSMapView,
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
            applyRegion(on: mapView, pins: pins, fitLayout: applyLayout, animated: animated)
        }

        func applyRegion(
            on mapView: GMSMapView,
            pins: [TripDetailMapPin],
            fitLayout: TripDetailMapFitLayout,
            animated: Bool
        ) {
            guard let bounds = TripDetailMapPresentation.gmsCoordinateBounds(for: pins) else { return }
            isApplyingRegion = true
            let update = GMSCameraUpdate.fit(
                bounds,
                with: TripDetailMapPresentation.uiMapFitEdgeInsets(for: fitLayout)
            )
            if animated {
                mapView.animate(with: update)
            } else {
                mapView.moveCamera(update)
            }
            isApplyingRegion = false
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            if let fitLayout = currentFitLayout, !pins.isEmpty {
                scheduleRegionApplyIfNeeded(
                    on: mapView,
                    pins: pins,
                    fitLayout: fitLayout,
                    animated: false
                )
            }
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            if let fitLayout = currentFitLayout, !pins.isEmpty {
                scheduleRegionApplyIfNeeded(
                    on: mapView,
                    pins: pins,
                    fitLayout: fitLayout,
                    animated: false
                )
            }
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            let siteID = marker.userData as? UUID
            let pinID = markersByPinID.first(where: { $0.value === marker })?.key ?? "unknown"
            let kind = pins.first(where: { $0.id == pinID })?.kind ?? .planned
            let title = marker.title ?? pinID

            TripDetailMapNavigationDebug.pinSelected(
                engine: .googleMaps,
                pinID: pinID,
                kind: kind,
                siteID: siteID,
                title: title
            )

            guard siteID != nil else {
                TripDetailMapNavigationDebug.pinIgnoredMissingSiteID(
                    engine: .googleMaps,
                    pinID: pinID,
                    kind: kind
                )
                return false
            }

            mapView.selectedMarker = marker
            selectedPinID = pinID
            return true
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            ExploreCatalogMapSiteCallout.makeGoogleInfoWindow(siteName: marker.title ?? "") { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                guard let siteID = marker.userData as? UUID else { return }
                onSiteSelected(siteID)
                mapView.selectedMarker = nil
                selectedPinID = nil
            }
        }

        func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
            guard let siteID = marker.userData as? UUID else { return }

            onSiteSelected(siteID)
            mapView.selectedMarker = nil
            selectedPinID = nil
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            mapView.selectedMarker = nil
            selectedPinID = nil
        }

        private static func markerTint(for kind: TripDetailMapPinKind) -> UIColor {
            kind == .planned ? .systemBlue : .systemRed
        }
    }
}

extension TripDetailMapPresentation {
    static func gmsCoordinateBounds(for pins: [TripDetailMapPin]) -> GMSCoordinateBounds? {
        guard let region = fittingRegion(for: pins) else { return nil }
        let halfLatitude = region.latitudeDelta / 2
        let halfLongitude = region.longitudeDelta / 2
        let northEast = CLLocationCoordinate2D(
            latitude: region.centerLatitude + halfLatitude,
            longitude: region.centerLongitude + halfLongitude
        )
        let southWest = CLLocationCoordinate2D(
            latitude: region.centerLatitude - halfLatitude,
            longitude: region.centerLongitude - halfLongitude
        )
        return GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
    }
}
#endif
