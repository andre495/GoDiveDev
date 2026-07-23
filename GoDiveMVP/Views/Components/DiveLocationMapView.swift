import MapKit
import SwiftUI

/// Map layer for a single dive: MapKit by default; Google Maps when **`GoogleMapsSecrets.plist`** (or launch arg) selects Google.
struct DiveLocationMapView: View {
    let coordinate: DiveCoordinate?
    /// Height from the **bottom** of **`layoutHeight`** covered by the sheet + home indicator (**points**).
    var bottomContentMargin: CGFloat = 0
    /// Height from the **top** of **`layoutHeight`** covered by status bar + dive toolbar (**points**).
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    /// Continuous overview panel height — drives zoom while the grabber moves.
    var sheetHeightFraction: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
    var largeRestingFraction: CGFloat = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
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
                sheetHeightFraction: sheetHeightFraction,
                largeRestingFraction: largeRestingFraction,
                isUserInteractionEnabled: isUserInteractionEnabled
            )
        } else {
            DiveLocationMapRepresentable(
                coordinate: coordinate,
                bottomContentMargin: bottomContentMargin,
                topObstructionHeight: topObstructionHeight,
                layoutHeight: layoutHeight,
                sheetHeightFraction: sheetHeightFraction,
                largeRestingFraction: largeRestingFraction,
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
