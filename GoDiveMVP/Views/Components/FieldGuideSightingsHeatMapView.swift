import MapKit
import SwiftUI

/// Sightings heat map — framed above the embedded overview panel (dive map tab pattern).
struct FieldGuideSightingsHeatMapView: View {
    let heatCells: [FieldGuideSightingsHeatPresentation.HeatRegionCell]
    let mapRegion: MKCoordinateRegion
    var bottomContentMargin: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    var isUserInteractionEnabled: Bool = true

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else {
                #if canImport(UIKit)
                FieldGuideSightingsHeatMapRepresentable(
                    heatCells: heatCells,
                    mapRegion: mapRegion,
                    bottomContentMargin: bottomContentMargin,
                    topObstructionHeight: topObstructionHeight,
                    layoutHeight: layoutHeight,
                    isUserInteractionEnabled: isUserInteractionEnabled
                )
                #else
                Color.clear
                #endif
            }
        }
        .accessibilityLabel("Sightings heat map")
        .accessibilityHint("Darker regions indicate more logged marine life sightings")
        .accessibilityIdentifier("FieldGuide.Sightings.HeatMap")
    }

    private var uiTestPlaceholder: some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }
}
