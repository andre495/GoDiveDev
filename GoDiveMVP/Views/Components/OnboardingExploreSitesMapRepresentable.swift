import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Read-only Explore-style map for onboarding — scripted region + pin callout only.
struct OnboardingExploreSitesMapRepresentable: UIViewRepresentable {
  let sites: [ExploreCatalogMapPresentation.PlottedSite]
  let region: DiveLocationMapRegionSpec
  let animateRegion: Bool
  let selectedSiteID: UUID?
  let regionToken: Int

  func makeCoordinator() -> Coordinator {
    Coordinator(sites: sites)
  }

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.preferredConfiguration = MKHybridMapConfiguration()
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.isScrollEnabled = false
    mapView.isZoomEnabled = false
    mapView.isUserInteractionEnabled = false
    mapView.showsCompass = false
    GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
    mapView.delegate = context.coordinator
    context.coordinator.installAnnotations(on: mapView)
    mapView.setRegion(region.mkCoordinateRegion, animated: false)
    context.coordinator.lastAppliedRegionToken = regionToken
    return mapView
  }

  func updateUIView(_ mapView: MKMapView, context: Context) {
    context.coordinator.applyRegionIfNeeded(
      on: mapView,
      region: region,
      token: regionToken,
      animated: animateRegion
    )
    context.coordinator.applySelection(on: mapView, selectedSiteID: selectedSiteID)
  }

  final class Coordinator: NSObject, MKMapViewDelegate {
    private let sites: [ExploreCatalogMapPresentation.PlottedSite]
    private var annotationsBySiteID: [UUID: ExploreDiveSiteMapAnnotation] = [:]
    var lastAppliedRegionToken: Int?
    private var lastSelectedSiteID: UUID?

    init(sites: [ExploreCatalogMapPresentation.PlottedSite]) {
      self.sites = sites
      super.init()
      for site in sites {
        annotationsBySiteID[site.id] = ExploreDiveSiteMapAnnotation(site: site)
      }
    }

    func installAnnotations(on mapView: MKMapView) {
      mapView.addAnnotations(Array(annotationsBySiteID.values))
    }

    func applyRegionIfNeeded(
      on mapView: MKMapView,
      region: DiveLocationMapRegionSpec,
      token: Int,
      animated: Bool
    ) {
      guard token != lastAppliedRegionToken else { return }
      lastAppliedRegionToken = token
      mapView.setRegion(region.mkCoordinateRegion, animated: animated)
    }

    func applySelection(on mapView: MKMapView, selectedSiteID: UUID?) {
      guard selectedSiteID != lastSelectedSiteID else { return }
      lastSelectedSiteID = selectedSiteID

      for annotation in mapView.selectedAnnotations {
        mapView.deselectAnnotation(annotation, animated: false)
      }

      guard let selectedSiteID,
            let annotation = annotationsBySiteID[selectedSiteID] else { return }
      mapView.selectAnnotation(annotation, animated: true)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      guard let siteAnnotation = annotation as? ExploreDiveSiteMapAnnotation else { return nil }

      let identifier = "OnboardingExplore.CalloutPin"
      let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      pinView.annotation = annotation
      pinView.image = ExploreCatalogMapSiteCallout.makeMapPinImage(isVisited: true)
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
      return pinView
    }
  }
}
#endif
