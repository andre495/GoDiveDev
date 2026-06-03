import GoogleMaps
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// **Explore** map backed by **`GMSMapView`** — first Google Maps spike on the experiment branch.
struct ExploreCatalogGoogleMapRepresentable: UIViewRepresentable {
    let sites: [ExploreCatalogMapPresentation.PlottedSite]
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
        context.coordinator.syncMarkers(on: mapView, sites: sites)
        context.coordinator.applyRegion(on: mapView, sites: sites, animated: false)
        context.coordinator.refreshLabelVisibility(on: mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let sitesChanged = context.coordinator.syncMarkers(on: mapView, sites: sites)
        if sitesChanged {
            context.coordinator.applyRegion(on: mapView, sites: sites, animated: true)
        } else {
            context.coordinator.refreshLabelVisibility(on: mapView)
        }
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var sites: [ExploreCatalogMapPresentation.PlottedSite] = []
        private var markersBySiteID: [UUID: GMSMarker] = [:]
        private var lastSitesSignature: String?
        private var lastLabeledSiteIDs: Set<UUID> = []
        private var lastLabelRefreshTimestamp: CFAbsoluteTime = 0
        private let labelRefreshMinimumInterval: CFAbsoluteTime = 0.1

        init(onSiteSelected: @escaping (UUID) -> Void) {
            self.onSiteSelected = onSiteSelected
        }

        @discardableResult
        func syncMarkers(on mapView: GMSMapView, sites: [ExploreCatalogMapPresentation.PlottedSite]) -> Bool {
            self.sites = sites
            let signature = sites.map(\.id.uuidString).sorted().joined(separator: "|")
            let sitesChanged = signature != lastSitesSignature
            guard sitesChanged else { return false }
            lastSitesSignature = signature
            lastLabeledSiteIDs = []

            for marker in markersBySiteID.values {
                marker.map = nil
            }
            markersBySiteID.removeAll()

            for site in sites {
                let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset()
                let marker = GMSMarker(
                    position: CLLocationCoordinate2D(
                        latitude: site.coordinate.latitude,
                        longitude: site.coordinate.longitude
                    )
                )
                marker.title = site.siteName
                marker.icon = pinOnly.image
                marker.groundAnchor = pinOnly.groundAnchor
                marker.userData = site.id
                marker.accessibilityLabel = site.siteName
                marker.map = mapView
                markersBySiteID[site.id] = marker
            }

            return true
        }

        func applyRegion(
            on mapView: GMSMapView,
            sites: [ExploreCatalogMapPresentation.PlottedSite],
            animated: Bool
        ) {
            guard let region = ExploreCatalogMapPresentation.boundingRegion(for: sites) else { return }
            let update = GMSCameraUpdate.fit(
                region.gmsCoordinateBounds,
                with: UIEdgeInsets(top: 48, left: 32, bottom: 48, right: 32)
            )
            if animated {
                mapView.animate(with: update)
            } else {
                mapView.moveCamera(update)
            }
        }

        func refreshLabelVisibility(on mapView: GMSMapView, force: Bool = false) {
            guard !sites.isEmpty else { return }

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
            let labeledSiteIDs = ExploreCatalogMapLabelVisibility.labeledSiteIDs(
                sites: sites,
                visibleLatitudeSpan: span,
                mapCenter: center
            )
            guard labeledSiteIDs != lastLabeledSiteIDs else { return }
            lastLabeledSiteIDs = labeledSiteIDs

            let scale = mapView.traitCollection.displayScale
            for site in sites {
                guard let marker = markersBySiteID[site.id] else { continue }
                if labeledSiteIDs.contains(site.id) {
                    let labeledPin = ExploreCatalogGoogleMapMarkerImageFactory.makeLabeledPinAsset(
                        siteName: site.siteName,
                        scale: scale
                    )
                    marker.icon = labeledPin.image
                    marker.groundAnchor = labeledPin.groundAnchor
                } else {
                    let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset()
                    marker.icon = pinOnly.image
                    marker.groundAnchor = pinOnly.groundAnchor
                }
            }
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            refreshLabelVisibility(on: mapView)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            refreshLabelVisibility(on: mapView, force: true)
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let siteID = marker.userData as? UUID else { return false }
            onSiteSelected(siteID)
            return true
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

private extension DiveLocationMapRegionSpec {
    var gmsCoordinateBounds: GMSCoordinateBounds {
        let halfLatitude = latitudeDelta / 2
        let halfLongitude = longitudeDelta / 2
        let northEast = CLLocationCoordinate2D(
            latitude: centerLatitude + halfLatitude,
            longitude: centerLongitude + halfLongitude
        )
        let southWest = CLLocationCoordinate2D(
            latitude: centerLatitude - halfLatitude,
            longitude: centerLongitude - halfLongitude
        )
        return GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
    }
}
#endif
