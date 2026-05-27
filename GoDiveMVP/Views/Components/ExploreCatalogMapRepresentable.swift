import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// **Explore** map: all catalog dive sites as standard red markers; tap opens site details.
struct ExploreCatalogMapRepresentable: UIViewRepresentable {
    let sites: [ExploreCatalogMapPresentation.PlottedSite]
    var onSiteSelected: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSiteSelected: onSiteSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKImageryMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.delegate = context.coordinator
        context.coordinator.syncAnnotations(on: mapView, sites: sites)
        context.coordinator.applyRegion(on: mapView, sites: sites, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let sitesChanged = context.coordinator.syncAnnotations(on: mapView, sites: sites)
        if sitesChanged {
            context.coordinator.applyRegion(on: mapView, sites: sites, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSiteSelected: (UUID) -> Void
        private var annotationsBySiteID: [UUID: ExploreDiveSiteMapAnnotation] = [:]
        private var lastSitesSignature: String?

        init(onSiteSelected: @escaping (UUID) -> Void) {
            self.onSiteSelected = onSiteSelected
        }

        @discardableResult
        func syncAnnotations(on mapView: MKMapView, sites: [ExploreCatalogMapPresentation.PlottedSite]) -> Bool {
            let signature = sites.map(\.id.uuidString).sorted().joined(separator: "|")
            guard signature != lastSitesSignature else { return false }
            lastSitesSignature = signature

            mapView.removeAnnotations(Array(annotationsBySiteID.values))
            annotationsBySiteID.removeAll()

            for site in sites {
                let annotation = ExploreDiveSiteMapAnnotation(site: site)
                annotationsBySiteID[site.id] = annotation
                mapView.addAnnotation(annotation)
            }
            return true
        }

        func applyRegion(
            on mapView: MKMapView,
            sites: [ExploreCatalogMapPresentation.PlottedSite],
            animated: Bool
        ) {
            guard let region = ExploreCatalogMapPresentation.region(for: sites) else { return }
            mapView.setRegion(region, animated: animated)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let siteAnnotation = annotation as? ExploreDiveSiteMapAnnotation else { return nil }

            let identifier = Self.standardMarkerReuseIdentifier
            let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            markerView.annotation = annotation
            markerView.markerTintColor = .systemRed
            markerView.canShowCallout = false
            markerView.accessibilityLabel = siteAnnotation.siteName
            return markerView
        }

        private static let standardMarkerReuseIdentifier = "ExploreCatalog.StandardMarker"

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let siteAnnotation = view.annotation as? ExploreDiveSiteMapAnnotation else { return }
            onSiteSelected(siteAnnotation.siteID)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}
#endif
