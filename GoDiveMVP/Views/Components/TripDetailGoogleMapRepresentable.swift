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
        context.coordinator.refreshLabelVisibility(on: mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let pinsChanged = context.coordinator.syncMarkers(on: mapView, pins: pins)
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

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var pins: [TripDetailMapPin] = []
        private var markersByPinID: [String: GMSMarker] = [:]
        private var lastPinsSignature: String?
        private var lastFitLayoutSignature: String?
        private var lastAppliedRegionSignature: String?
        private var lastLabeledPinIDs: Set<String> = []
        private var lastLabelRefreshTimestamp: CFAbsoluteTime = 0
        private let labelRefreshMinimumInterval: CFAbsoluteTime = 0.1
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
            lastLabeledPinIDs = []

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
            refreshLabelVisibility(on: mapView, force: true)
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

        func refreshLabelVisibility(on mapView: GMSMapView, force: Bool = false) {
            guard !pins.isEmpty else { return }

            let now = CFAbsoluteTimeGetCurrent()
            if !force, now - lastLabelRefreshTimestamp < labelRefreshMinimumInterval {
                return
            }
            lastLabelRefreshTimestamp = now

            let span = Self.visibleLatitudeSpan(on: mapView)
            let center = DiveCoordinate(
                latitude: mapView.camera.target.latitude,
                longitude: mapView.camera.target.longitude
            )
            let labeledPinIDs = ExploreCatalogMapLabelVisibility.labeledTripPinIDs(
                pins: pins,
                visibleLatitudeSpan: span,
                mapCenter: center
            )
            guard labeledPinIDs != lastLabeledPinIDs else { return }
            lastLabeledPinIDs = labeledPinIDs

            let scale = mapView.traitCollection.displayScale
            for pin in pins {
                guard let marker = markersByPinID[pin.id] else { continue }
                let tint = Self.markerTint(for: pin.kind)
                if labeledPinIDs.contains(pin.id) {
                    let labeledPin = ExploreCatalogGoogleMapMarkerImageFactory.makeLabeledPinAsset(
                        siteName: pin.title,
                        tint: tint,
                        scale: scale
                    )
                    marker.icon = labeledPin.image
                    marker.groundAnchor = labeledPin.groundAnchor
                } else {
                    let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset(tint: tint)
                    marker.icon = pinOnly.image
                    marker.groundAnchor = pinOnly.groundAnchor
                }
            }
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            guard !isApplyingRegion else { return }
            refreshLabelVisibility(on: mapView)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            guard !isApplyingRegion else { return }
            refreshLabelVisibility(on: mapView, force: true)
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

            guard let siteID else {
                TripDetailMapNavigationDebug.pinIgnoredMissingSiteID(
                    engine: .googleMaps,
                    pinID: pinID,
                    kind: kind
                )
                return false
            }

            onSiteSelected(siteID)
            return true
        }

        private static func markerTint(for kind: TripDetailMapPinKind) -> UIColor {
            kind == .planned ? .systemBlue : .systemRed
        }

        private static func visibleLatitudeSpan(on mapView: GMSMapView) -> Double {
            let region = mapView.projection.visibleRegion()
            let latitudes = [
                region.farLeft.latitude,
                region.farRight.latitude,
                region.nearLeft.latitude,
                region.nearRight.latitude,
            ]
            guard let maxLatitude = latitudes.max(), let minLatitude = latitudes.min() else { return .greatestFiniteMagnitude }
            return max(0, maxLatitude - minLatitude)
        }
    }
}

extension TripDetailMapPresentation {
    static func gmsCoordinateBounds(for pins: [TripDetailMapPin]) -> GMSCoordinateBounds? {
        guard let region = boundingRegion(for: pins) else { return nil }
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
