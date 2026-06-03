import MapKit
import SwiftUI

/// Map layer for a single dive: MapKit by default; Google Maps when **`GoDiveMapEngine`** + API key are set.
struct DiveLocationMapView: View {
    let coordinate: DiveCoordinate?
    /// Height from the **bottom** of **`layoutHeight`** covered by the sheet + home indicator (**points**).
    var bottomContentMargin: CGFloat = 0
    /// Height from the **top** of **`layoutHeight`** covered by status bar + dive toolbar (**points**).
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    /// Resting sheet detent — camera reframes when this changes (not on every layout tick).
    var cameraLayoutDetent: DiveActivityOverviewDetent = .medium
    /// When **`false`**, the map does not accept pan/zoom (dive overview at medium/large detents).
    var isUserInteractionEnabled: Bool = true

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestMapPlaceholder
            } else {
                liveMap
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var liveMap: some View {
        #if canImport(UIKit)
        if GoDiveMapEngine.active == .googleMaps, GoogleMapsBootstrap.loadAPIKey() != nil {
            DiveLocationGoogleMapRepresentable(
                coordinate: coordinate,
                bottomContentMargin: bottomContentMargin,
                topObstructionHeight: topObstructionHeight,
                layoutHeight: layoutHeight,
                cameraLayoutDetent: cameraLayoutDetent,
                isUserInteractionEnabled: isUserInteractionEnabled
            )
        } else {
            DiveLocationMapRepresentable(
                coordinate: coordinate,
                bottomContentMargin: bottomContentMargin,
                topObstructionHeight: topObstructionHeight,
                layoutHeight: layoutHeight,
                cameraLayoutDetent: cameraLayoutDetent,
                isUserInteractionEnabled: isUserInteractionEnabled
            )
        }
        #else
        Color.clear
        #endif
    }

    private var uiTestMapPlaceholder: some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private var accessibilityLabelText: String {
        if let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) {
            return "Map showing dive location at \(coordinate.latitude), \(coordinate.longitude)"
        }
        return "Map with no dive location recorded"
    }
}

/// Shared MapKit base layer for **Explore** and dive overview maps.
enum DiveOverviewMapStyle {
    static let mapStyle = MapStyle.imagery(elevation: .realistic)
}
