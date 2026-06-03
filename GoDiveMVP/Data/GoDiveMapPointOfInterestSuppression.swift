import Foundation

/// Hides third-party map POIs (stores, restaurants, transit pins) so only GoDive dive-site markers stand out.
enum GoDiveMapPointOfInterestSuppression: Sendable {
    /// JSON style for **`GMSMapView.mapStyle`** — hides business and other POI icons/labels.
    /// Note: local JSON styling applies to the **normal** map layer; **`hybrid`** may still show some
    /// base-map POIs until a Cloud Console **map ID** with POI visibility off is configured
    /// (**`GoogleMapsBootstrap.loadMapID()`**).
    nonisolated static let googleMapsSuppressPOIStyleJSON = """
    [
      {
        "featureType": "poi.business",
        "elementType": "all",
        "stylers": [{ "visibility": "off" }]
      },
      {
        "featureType": "poi",
        "elementType": "labels.icon",
        "stylers": [{ "visibility": "off" }]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text",
        "stylers": [{ "visibility": "off" }]
      },
      {
        "featureType": "transit",
        "elementType": "all",
        "stylers": [{ "visibility": "off" }]
      }
    ]
    """
}

#if canImport(MapKit)
import MapKit

extension GoDiveMapPointOfInterestSuppression {
    static func applyToMapKit(_ mapView: MKMapView) {
        mapView.pointOfInterestFilter = .excludingAll
    }
}
#endif

#if canImport(GoogleMaps)
import GoogleMaps

extension GoDiveMapPointOfInterestSuppression {
    /// Creates a **`GMSMapView`**, using an optional Cloud **map ID** when configured in secrets.
    static func makeGoogleMapView() -> GMSMapView {
        let options = GMSMapViewOptions()
        options.frame = .zero
        options.camera = GMSCameraPosition(latitude: 0, longitude: 0, zoom: 2)
        if let mapIDString = GoogleMapsBootstrap.loadMapID() {
            options.mapID = GMSMapID(identifier: mapIDString)
        }
        return GMSMapView(options: options)
    }

    /// Applies embedded JSON POI suppression. Skipped when a Cloud **map ID** owns styling.
    static func applyToGoogleMaps(_ mapView: GMSMapView) {
        guard GoogleMapsBootstrap.loadMapID() == nil else { return }
        mapView.mapStyle = try? GMSMapStyle(jsonString: googleMapsSuppressPOIStyleJSON)
    }
}
#endif
