import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// **Explore** map: all catalog dive sites as standard red markers; tap opens site details.
struct ExploreCatalogMapRepresentable: UIViewRepresentable {
    let sites: [ExploreCatalogMapPresentation.PlottedSite]
    let sitesChangeSignature: String
    let pinLabelPolicy: ExploreCatalogMapPinLabelPolicy
    let usesPinCallout: Bool
    var focusRequest: ExploreCatalogMapFocusRequest?
    var onSiteSelected: (ExploreMapSiteSelection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            pinLabelPolicy: pinLabelPolicy,
            usesPinCallout: usesPinCallout,
            onSiteSelected: onSiteSelected
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKHybridMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
        mapView.delegate = context.coordinator
        context.coordinator.syncAnnotations(
            on: mapView,
            sites: sites,
            sitesChangeSignature: sitesChangeSignature
        )
        context.coordinator.applyRegion(on: mapView, sites: sites, animated: false)
        context.coordinator.refreshMapPresentation(on: mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let interactionChanged = context.coordinator.updateInteraction(
            pinLabelPolicy: pinLabelPolicy,
            usesPinCallout: usesPinCallout
        )
        let sitesChanged = context.coordinator.syncAnnotations(
            on: mapView,
            sites: sites,
            sitesChangeSignature: sitesChangeSignature
        )
        let focusPending = context.coordinator.isFocusRequestPending(focusRequest)
        if sitesChanged, !focusPending {
            context.coordinator.applyRegion(on: mapView, sites: sites, animated: true)
        }
        if sitesChanged || interactionChanged, !focusPending {
            context.coordinator.deselectAllAnnotations(on: mapView)
        }
        context.coordinator.refreshMapPresentation(on: mapView, force: sitesChanged || interactionChanged)
        context.coordinator.applyFocusRequestIfNeeded(
            on: mapView,
            focusRequest: focusRequest,
            sites: sites
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSiteSelected: (ExploreMapSiteSelection) -> Void
        private var pinLabelPolicy: ExploreCatalogMapPinLabelPolicy
        private var usesPinCallout: Bool
        private var sites: [ExploreCatalogMapPresentation.PlottedSite] = []
        private var sitesByID: [UUID: ExploreCatalogMapPresentation.PlottedSite] = [:]
        private var annotationsBySiteID: [UUID: ExploreDiveSiteMapAnnotation] = [:]
        private var lastSitesSignature: String?
        private var visibleSiteIDs: Set<UUID> = []
        private var labeledSiteIDs: Set<UUID> = []
        private var selectedSiteID: UUID?
        private var lastAppliedFocusRequestID: UUID?
        private var stickyPinVisibility = ExploreCatalogMapStickyPinVisibility.State()
        private var lastPresentationRefreshTimestamp: CFAbsoluteTime = 0
        private let presentationRefreshMinimumInterval: CFAbsoluteTime = 0.08

        init(
            pinLabelPolicy: ExploreCatalogMapPinLabelPolicy,
            usesPinCallout: Bool,
            onSiteSelected: @escaping (ExploreMapSiteSelection) -> Void
        ) {
            self.pinLabelPolicy = pinLabelPolicy
            self.usesPinCallout = usesPinCallout
            self.onSiteSelected = onSiteSelected
        }

        @discardableResult
        func updateInteraction(
            pinLabelPolicy: ExploreCatalogMapPinLabelPolicy,
            usesPinCallout: Bool
        ) -> Bool {
            let changed = self.pinLabelPolicy != pinLabelPolicy || self.usesPinCallout != usesPinCallout
            self.pinLabelPolicy = pinLabelPolicy
            self.usesPinCallout = usesPinCallout
            if changed {
                visibleSiteIDs = []
                labeledSiteIDs = []
                selectedSiteID = nil
                ExploreCatalogMapStickyPinVisibility.reset(&stickyPinVisibility)
            }
            return changed
        }

        @discardableResult
        func syncAnnotations(
            on mapView: MKMapView,
            sites: [ExploreCatalogMapPresentation.PlottedSite],
            sitesChangeSignature: String
        ) -> Bool {
            self.sites = sites
            sitesByID = Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) })
            let sitesChanged = sitesChangeSignature != lastSitesSignature
            guard sitesChanged else { return false }
            lastSitesSignature = sitesChangeSignature
            visibleSiteIDs = []
            labeledSiteIDs = []
            selectedSiteID = nil
            ExploreCatalogMapStickyPinVisibility.reset(&stickyPinVisibility)

            mapView.removeAnnotations(Array(annotationsBySiteID.values))
            annotationsBySiteID.removeAll()

            if !pinLabelPolicy.usesDynamicPinDensity {
                for site in sites {
                    annotationsBySiteID[site.id] = ExploreDiveSiteMapAnnotation(site: site)
                }
                mapView.addAnnotations(Array(annotationsBySiteID.values))
            }

            return true
        }

        private func annotation(for siteID: UUID) -> ExploreDiveSiteMapAnnotation? {
            if let cached = annotationsBySiteID[siteID] {
                return cached
            }
            guard let site = sitesByID[siteID] else { return nil }
            let created = ExploreDiveSiteMapAnnotation(site: site)
            annotationsBySiteID[siteID] = created
            return created
        }

        func applyRegion(
            on mapView: MKMapView,
            sites: [ExploreCatalogMapPresentation.PlottedSite],
            animated: Bool
        ) {
            guard let region = ExploreCatalogMapPresentation.region(for: sites) else { return }
            mapView.setRegion(region, animated: animated)
        }

        func applyFocusRequestIfNeeded(
            on mapView: MKMapView,
            focusRequest: ExploreCatalogMapFocusRequest?,
            sites: [ExploreCatalogMapPresentation.PlottedSite]
        ) {
            guard let focusRequest else { return }
            guard focusRequest.requestID != lastAppliedFocusRequestID else { return }
            guard let site = sites.first(where: { $0.selection == focusRequest.selection }) else { return }

            lastAppliedFocusRequestID = focusRequest.requestID

            let region = DiveLocationMapRegionSpec(
                centerLatitude: focusRequest.coordinate.latitude,
                centerLongitude: focusRequest.coordinate.longitude,
                latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
                longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
            )
            mapView.setRegion(region.mkCoordinateRegion, animated: true)

            guard let annotation = annotationsBySiteID[site.id] ?? annotation(for: site.id) else { return }
            if !mapView.annotations.contains(where: { ($0 as? ExploreDiveSiteMapAnnotation)?.siteID == site.id }) {
                mapView.addAnnotation(annotation)
            }
            visibleSiteIDs.insert(site.id)

            if usesPinCallout {
                mapView.selectAnnotation(annotation, animated: true)
                selectedSiteID = site.id
            }
        }

        func isFocusRequestPending(_ focusRequest: ExploreCatalogMapFocusRequest?) -> Bool {
            guard let focusRequest else { return false }
            return focusRequest.requestID != lastAppliedFocusRequestID
        }

        func deselectAllAnnotations(on mapView: MKMapView) {
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            selectedSiteID = nil
        }

        func refreshMapPresentation(on mapView: MKMapView, force: Bool = false) {
            guard !sites.isEmpty else { return }

            let now = CFAbsoluteTimeGetCurrent()
            if !force, now - lastPresentationRefreshTimestamp < presentationRefreshMinimumInterval {
                return
            }
            lastPresentationRefreshTimestamp = now

            let viewport = Self.viewport(from: mapView)
            let freshEligible = pinLabelPolicy.visibleSiteIDs(
                sites: sites,
                viewport: viewport
            )
            let updatedVisibleSiteIDs: Set<UUID>
            if pinLabelPolicy.usesDynamicPinDensity {
                updatedVisibleSiteIDs = ExploreCatalogMapStickyPinVisibility.visibleSiteIDs(
                    sites: sites,
                    viewport: viewport,
                    freshEligible: freshEligible,
                    state: &stickyPinVisibility
                )
            } else {
                updatedVisibleSiteIDs = freshEligible
            }
            let updatedLabeledSiteIDs = pinLabelPolicy.labeledSiteIDs(
                sites: sites,
                visibleLatitudeSpan: viewport.latitudeSpan,
                mapCenter: viewport.center
            )

            let visibilityChanged = updatedVisibleSiteIDs != visibleSiteIDs
            let labelsChanged = updatedLabeledSiteIDs != labeledSiteIDs
            guard visibilityChanged || labelsChanged else { return }

            if visibilityChanged {
                visibleSiteIDs = updatedVisibleSiteIDs
                syncVisibleAnnotations(on: mapView)
            }

            if labelsChanged {
                labeledSiteIDs = updatedLabeledSiteIDs
            }

            refreshAnnotationViews(on: mapView)
        }

        private func syncVisibleAnnotations(on mapView: MKMapView) {
            guard pinLabelPolicy.usesDynamicPinDensity else { return }

            let onMap = Set(
                mapView.annotations.compactMap { ($0 as? ExploreDiveSiteMapAnnotation)?.siteID }
            )

            for siteID in visibleSiteIDs where !onMap.contains(siteID) {
                guard let annotation = annotation(for: siteID) else { continue }
                mapView.addAnnotation(annotation)
            }

            for siteID in onMap where !visibleSiteIDs.contains(siteID) {
                if siteID == selectedSiteID { continue }
                guard let annotation = annotationsBySiteID[siteID] else { continue }
                if mapView.selectedAnnotations.contains(where: { ($0 as? ExploreDiveSiteMapAnnotation)?.siteID == siteID }) {
                    mapView.deselectAnnotation(annotation, animated: false)
                    selectedSiteID = nil
                }
                mapView.removeAnnotation(annotation)
            }
        }

        func refreshAnnotationViews(on mapView: MKMapView) {
            for annotation in mapView.annotations {
                guard let siteAnnotation = annotation as? ExploreDiveSiteMapAnnotation else { continue }
                if let markerView = mapView.view(for: annotation) as? MKMarkerAnnotationView {
                    applyMarkerPresentation(to: markerView, siteAnnotation: siteAnnotation)
                } else if let pinView = mapView.view(for: annotation) {
                    applyCalloutPinPresentation(to: pinView, siteAnnotation: siteAnnotation)
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let siteAnnotation = annotation as? ExploreDiveSiteMapAnnotation else { return nil }

            if usesPinCallout {
                let identifier = Self.calloutPinReuseIdentifier
                let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                pinView.annotation = annotation
                applyCalloutPinPresentation(to: pinView, siteAnnotation: siteAnnotation)
                return pinView
            }

            let identifier = Self.standardMarkerReuseIdentifier
            let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            markerView.annotation = annotation
            applyMarkerPresentation(to: markerView, siteAnnotation: siteAnnotation)
            return markerView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            refreshMapPresentation(on: mapView)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let siteAnnotation = view.annotation as? ExploreDiveSiteMapAnnotation else { return }
            guard usesPinCallout else {
                onSiteSelected(siteAnnotation.selection)
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }
            selectedSiteID = siteAnnotation.siteID
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let siteAnnotation = view.annotation as? ExploreDiveSiteMapAnnotation else { return }
            if selectedSiteID == siteAnnotation.siteID {
                selectedSiteID = nil
            }
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            calloutAccessoryControlTapped control: UIControl
        ) {
            guard usesPinCallout,
                  let siteAnnotation = view.annotation as? ExploreDiveSiteMapAnnotation else { return }
            onSiteSelected(siteAnnotation.selection)
            mapView.deselectAnnotation(view.annotation, animated: true)
            selectedSiteID = nil
        }

        private func applyCalloutPinPresentation(
            to pinView: MKAnnotationView,
            siteAnnotation: ExploreDiveSiteMapAnnotation
        ) {
            pinView.image = ExploreCatalogMapSiteCallout.makeMapPinImage(isVisited: siteAnnotation.isVisited)
            let imageHeight = pinView.image?.size.height ?? 32
            pinView.centerOffset = CGPoint(x: 0, y: -imageHeight / 2)
            pinView.canShowCallout = true
            pinView.rightCalloutAccessoryView = nil
            pinView.detailCalloutAccessoryView = ExploreCatalogMapSiteCallout.makeMapKitCalloutAccessory(
                siteName: siteAnnotation.siteName
            )
            pinView.accessibilityLabel = ExploreCatalogMapPinAppearance.accessibilityLabel(
                siteName: siteAnnotation.siteName,
                isVisited: siteAnnotation.isVisited
            )
        }

        private func applyMarkerPresentation(
            to markerView: MKMarkerAnnotationView,
            siteAnnotation: ExploreDiveSiteMapAnnotation
        ) {
            markerView.markerTintColor = ExploreCatalogMapPinAppearance.pinTintColor(
                isVisited: siteAnnotation.isVisited
            )
            markerView.subtitleVisibility = .hidden
            markerView.displayPriority = .defaultHigh
            markerView.accessibilityLabel = ExploreCatalogMapPinAppearance.accessibilityLabel(
                siteName: siteAnnotation.siteName,
                isVisited: siteAnnotation.isVisited
            )
            markerView.titleVisibility = labeledSiteIDs.contains(siteAnnotation.siteID) ? .visible : .hidden
            markerView.canShowCallout = false
            markerView.rightCalloutAccessoryView = nil
        }

        private static func viewport(from mapView: MKMapView) -> ExploreCatalogMapViewport {
            ExploreCatalogMapViewport(
                center: DiveCoordinate(
                    latitude: mapView.region.center.latitude,
                    longitude: mapView.region.center.longitude
                ),
                latitudeSpan: mapView.region.span.latitudeDelta,
                longitudeSpan: mapView.region.span.longitudeDelta
            )
        }

        private static let standardMarkerReuseIdentifier = "ExploreCatalog.StandardMarker"
        private static let calloutPinReuseIdentifier = "ExploreCatalog.CalloutPin"
    }
}
#endif
