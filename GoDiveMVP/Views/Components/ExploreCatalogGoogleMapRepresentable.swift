import GoogleMaps
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// **Explore** map backed by **`GMSMapView`** — first Google Maps spike on the experiment branch.
struct ExploreCatalogGoogleMapRepresentable: UIViewRepresentable {
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
        context.coordinator.syncMarkers(
            on: mapView,
            sites: sites,
            sitesChangeSignature: sitesChangeSignature
        )
        context.coordinator.applyRegion(on: mapView, sites: sites, animated: false)
        context.coordinator.refreshMapPresentation(on: mapView, force: true)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onSiteSelected = onSiteSelected
        let interactionChanged = context.coordinator.updateInteraction(
            pinLabelPolicy: pinLabelPolicy,
            usesPinCallout: usesPinCallout
        )
        let sitesChanged = context.coordinator.syncMarkers(
            on: mapView,
            sites: sites,
            sitesChangeSignature: sitesChangeSignature
        )
        let focusPending = context.coordinator.isFocusRequestPending(focusRequest)
        if sitesChanged, !focusPending {
            context.coordinator.applyRegion(on: mapView, sites: sites, animated: true)
        }
        if sitesChanged || interactionChanged, !focusPending {
            mapView.selectedMarker = nil
        }
        context.coordinator.refreshMapPresentation(on: mapView, force: sitesChanged || interactionChanged)
        context.coordinator.applyFocusRequestIfNeeded(
            on: mapView,
            focusRequest: focusRequest,
            sites: sites
        )
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onSiteSelected: (ExploreMapSiteSelection) -> Void
        private var pinLabelPolicy: ExploreCatalogMapPinLabelPolicy
        private var usesPinCallout: Bool
        private var sites: [ExploreCatalogMapPresentation.PlottedSite] = []
        private var sitesByID: [UUID: ExploreCatalogMapPresentation.PlottedSite] = [:]
        private var markersBySiteID: [UUID: GMSMarker] = [:]
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
        func syncMarkers(
            on mapView: GMSMapView,
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

            for marker in markersBySiteID.values {
                marker.map = nil
            }
            markersBySiteID.removeAll()

            if !pinLabelPolicy.usesDynamicPinDensity {
                for site in sites {
                    let marker = makeMarker(for: site)
                    markersBySiteID[site.id] = marker
                    marker.map = mapView
                }
            }

            return true
        }

        private func makeMarker(for site: ExploreCatalogMapPresentation.PlottedSite) -> GMSMarker {
            let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset(
                tint: ExploreCatalogMapPinAppearance.pinTintColor(isVisited: site.isVisited)
            )
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
            marker.accessibilityLabel = ExploreCatalogMapPinAppearance.accessibilityLabel(
                siteName: site.siteName,
                isVisited: site.isVisited
            )
            marker.tracksInfoWindowChanges = usesPinCallout
            return marker
        }

        private func marker(for siteID: UUID) -> GMSMarker? {
            if let cached = markersBySiteID[siteID] {
                return cached
            }
            guard let site = sitesByID[siteID] else { return nil }
            let created = makeMarker(for: site)
            markersBySiteID[siteID] = created
            return created
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

        func applyFocusRequestIfNeeded(
            on mapView: GMSMapView,
            focusRequest: ExploreCatalogMapFocusRequest?,
            sites: [ExploreCatalogMapPresentation.PlottedSite]
        ) {
            guard let focusRequest else { return }
            guard focusRequest.requestID != lastAppliedFocusRequestID else { return }
            guard let site = sites.first(where: { $0.selection == focusRequest.selection }) else { return }
            guard let marker = markersBySiteID[site.id] ?? marker(for: site.id) else { return }

            lastAppliedFocusRequestID = focusRequest.requestID

            let region = DiveLocationMapRegionSpec(
                centerLatitude: focusRequest.coordinate.latitude,
                centerLongitude: focusRequest.coordinate.longitude,
                latitudeDelta: DiveLocationMapPresentation.diveSiteLatitudeDelta,
                longitudeDelta: DiveLocationMapPresentation.diveSiteLongitudeDelta
            )
            let update = GMSCameraUpdate.fit(
                region.gmsCoordinateBounds,
                with: UIEdgeInsets(top: 48, left: 32, bottom: 48, right: 32)
            )
            mapView.animate(with: update)

            marker.map = mapView
            visibleSiteIDs.insert(site.id)

            if usesPinCallout {
                mapView.selectedMarker = marker
                selectedSiteID = site.id
            }
        }

        func isFocusRequestPending(_ focusRequest: ExploreCatalogMapFocusRequest?) -> Bool {
            guard let focusRequest else { return false }
            return focusRequest.requestID != lastAppliedFocusRequestID
        }

        func refreshMapPresentation(on mapView: GMSMapView, force: Bool = false) {
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
                syncVisibleMarkers(on: mapView)
            }

            if labelsChanged {
                labeledSiteIDs = updatedLabeledSiteIDs
                applyLabelIcons(on: mapView)
            } else if pinLabelPolicy.usesDynamicPinDensity {
                applyPinOnlyIcons(on: mapView)
            }
        }

        private func syncVisibleMarkers(on mapView: GMSMapView) {
            guard pinLabelPolicy.usesDynamicPinDensity else { return }

            for siteID in visibleSiteIDs.union(selectedSiteID.map { Set([$0]) } ?? []) {
                guard let marker = marker(for: siteID) else { continue }
                if marker.map == nil {
                    marker.map = mapView
                }
            }

            for (siteID, marker) in markersBySiteID {
                let shouldShow = visibleSiteIDs.contains(siteID) || siteID == selectedSiteID
                guard !shouldShow else { continue }
                if mapView.selectedMarker === marker {
                    mapView.selectedMarker = nil
                }
                marker.map = nil
            }
        }

        private func applyLabelIcons(on mapView: GMSMapView) {
            guard pinLabelPolicy == .progressiveZoomReveal else { return }

            let scale = mapView.traitCollection.displayScale
            for site in sites {
                guard let marker = markersBySiteID[site.id], marker.map != nil else { continue }
                let tint = ExploreCatalogMapPinAppearance.pinTintColor(isVisited: site.isVisited)
                if labeledSiteIDs.contains(site.id) {
                    let labeledPin = ExploreCatalogGoogleMapMarkerImageFactory.makeLabeledPinAsset(
                        siteName: site.siteName,
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

        private func applyPinOnlyIcons(on mapView: GMSMapView) {
            for siteID in visibleSiteIDs {
                guard let marker = markersBySiteID[siteID],
                      marker.map != nil,
                      let site = sitesByID[siteID] else { continue }
                let pinOnly = ExploreCatalogGoogleMapMarkerImageFactory.makePinOnlyAsset(
                    tint: ExploreCatalogMapPinAppearance.pinTintColor(isVisited: site.isVisited)
                )
                marker.icon = pinOnly.image
                marker.groundAnchor = pinOnly.groundAnchor
            }
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            refreshMapPresentation(on: mapView)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            refreshMapPresentation(on: mapView, force: true)
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let siteID = marker.userData as? UUID,
                  let site = sites.first(where: { $0.id == siteID }) else { return false }
            if usesPinCallout {
                mapView.selectedMarker = marker
                selectedSiteID = siteID
                return true
            }
            onSiteSelected(site.selection)
            return true
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            guard usesPinCallout else { return nil }
            return ExploreCatalogMapSiteCallout.makeGoogleInfoWindow(siteName: marker.title ?? "") { [weak self, weak mapView] in
                guard let self, let mapView else { return }
                guard let siteID = marker.userData as? UUID,
                      let site = sites.first(where: { $0.id == siteID }) else { return }
                onSiteSelected(site.selection)
                mapView.selectedMarker = nil
                selectedSiteID = nil
            }
        }

        func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
            guard usesPinCallout,
                  let siteID = marker.userData as? UUID,
                  let site = sites.first(where: { $0.id == siteID }) else { return }
            onSiteSelected(site.selection)
            mapView.selectedMarker = nil
            selectedSiteID = nil
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            mapView.selectedMarker = nil
            selectedSiteID = nil
        }

        private static func viewport(from mapView: GMSMapView) -> ExploreCatalogMapViewport {
            let region = mapView.projection.visibleRegion()
            let latitudes = [
                region.farLeft.latitude,
                region.farRight.latitude,
                region.nearLeft.latitude,
                region.nearRight.latitude,
            ]
            let longitudes = [
                region.farLeft.longitude,
                region.farRight.longitude,
                region.nearLeft.longitude,
                region.nearRight.longitude,
            ]
            let minLatitude = latitudes.min() ?? mapView.camera.target.latitude
            let maxLatitude = latitudes.max() ?? mapView.camera.target.latitude
            let minLongitude = longitudes.min() ?? mapView.camera.target.longitude
            let maxLongitude = longitudes.max() ?? mapView.camera.target.longitude
            return ExploreCatalogMapViewport(
                center: DiveCoordinate(
                    latitude: mapView.camera.target.latitude,
                    longitude: mapView.camera.target.longitude
                ),
                latitudeSpan: max(0, maxLatitude - minLatitude),
                longitudeSpan: max(0, maxLongitude - minLongitude)
            )
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
