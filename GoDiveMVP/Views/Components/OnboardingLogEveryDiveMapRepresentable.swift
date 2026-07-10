import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Read-only dive-overview map for the **Log every dive** onboarding micro-demo.
struct OnboardingLogEveryDiveMapRepresentable: UIViewRepresentable {
  let coordinate: DiveCoordinate
  let region: DiveLocationMapRegionSpec

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.preferredConfiguration = MKImageryMapConfiguration()
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.isScrollEnabled = false
    mapView.isZoomEnabled = false
    mapView.isUserInteractionEnabled = false
    mapView.showsCompass = false
    GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
    mapView.delegate = context.coordinator
    mapView.setRegion(region.mkCoordinateRegion, animated: false)

    let annotation = MKPointAnnotation()
    annotation.coordinate = CLLocationCoordinate2D(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
    annotation.title = OnboardingLogEveryDiveDemoFixtures.focusedDiveName
    mapView.addAnnotation(annotation)

    return mapView
  }

  func updateUIView(_ mapView: MKMapView, context: Context) {}

  final class Coordinator: NSObject, MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      guard !(annotation is MKUserLocation) else { return nil }

      let identifier = "OnboardingLogEveryDive.Marker"
      let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      markerView.annotation = annotation
      markerView.markerTintColor = .systemRed
      markerView.titleVisibility = .visible
      markerView.subtitleVisibility = .hidden
      markerView.canShowCallout = false
      markerView.accessibilityLabel = "Dive site, \(OnboardingLogEveryDiveDemoFixtures.focusedDiveName)"
      return markerView
    }
  }
}
#endif
