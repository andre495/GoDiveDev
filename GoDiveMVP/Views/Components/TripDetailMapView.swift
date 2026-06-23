import SwiftUI

/// Top-of-page trip map — planned catalog sites (blue) and linked dives (red).
struct TripDetailMapView: View {
    let pins: [TripDetailMapPin]
    let fitLayout: TripDetailMapFitLayout
    var onSiteSelected: (UUID) -> Void

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else if GoDiveMapEngine.active == .googleMaps, GoogleMapsBootstrap.loadAPIKey() != nil {
                #if canImport(UIKit)
                TripDetailGoogleMapRepresentable(
                    pins: pins,
                    fitLayout: fitLayout,
                    onSiteSelected: onSiteSelected
                )
                #else
                Color.clear
                #endif
            } else {
                #if canImport(UIKit)
                TripDetailMapRepresentable(
                    pins: pins,
                    fitLayout: fitLayout,
                    onSiteSelected: onSiteSelected
                )
                #else
                Color.clear
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel(TripDetailMapPresentation.accessibilityLabel(for: pins))
        .accessibilityHint("Tap a site marker to preview its name, then open details from the callout")
        .accessibilityIdentifier("TripDetail.Map")
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

extension TripDetailMapPresentation {
    nonisolated static func accessibilityLabel(for pins: [TripDetailMapPin]) -> String {
        let plannedCount = pins.filter { $0.kind == .planned }.count
        let completedCount = pins.filter { $0.kind == .completed }.count
        switch (plannedCount, completedCount) {
        case (0, 0):
            return "Trip map"
        case (_, 0):
            return "Trip map, \(plannedCount) planned dive sites"
        case (0, _):
            return "Trip map, \(completedCount) completed dives"
        default:
            return "Trip map, \(plannedCount) planned dive sites, \(completedCount) completed dives"
        }
    }
}
