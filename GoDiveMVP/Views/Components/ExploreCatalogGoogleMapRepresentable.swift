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
        let mapView = GMSMapView(frame: .zero)
        mapView.mapType = .satellite
        mapView.isBuildingsEnabled = false
        mapView.isIndoorEnabled = false
        mapView.settings.rotateGestures = false
        mapView.settings.tiltGestures = false
        mapView.settings.compassButton = false
        mapView.delegate = context.coordinator
        context.coordinator.syncMarkers(on: mapView, sites: sites)
        context.coordinator.applyRegion(on: mapView, sites: sites, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let sitesChanged = context.coordinator.syncMarkers(on: mapView, sites: sites)
        if sitesChanged {
            context.coordinator.applyRegion(on: mapView, sites: sites, animated: true)
        }
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var markersBySiteID: [UUID: GMSMarker] = [:]
        private var lastSitesSignature: String?

        init(onSiteSelected: @escaping (UUID) -> Void) {
            self.onSiteSelected = onSiteSelected
        }

        @discardableResult
        func syncMarkers(on mapView: GMSMapView, sites: [ExploreCatalogMapPresentation.PlottedSite]) -> Bool {
            let signature = sites.map(\.id.uuidString).sorted().joined(separator: "|")
            guard signature != lastSitesSignature else { return false }
            lastSitesSignature = signature

            for marker in markersBySiteID.values {
                marker.map = nil
            }
            markersBySiteID.removeAll()

            for site in sites {
                let marker = GMSMarker(
                    position: CLLocationCoordinate2D(
                        latitude: site.coordinate.latitude,
                        longitude: site.coordinate.longitude
                    )
                )
                marker.title = site.siteName
                marker.icon = GMSMarker.markerImage(with: .systemRed)
                marker.userData = site.id
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

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let siteID = marker.userData as? UUID else { return false }
            onSiteSelected(siteID)
            return true
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
