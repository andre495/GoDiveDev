import SwiftUI

/// Full-bleed **Explore** map with catalog dive-site pins.
struct ExploreCatalogMapView: View {
    let sites: [ExploreCatalogMapPresentation.PlottedSite]
    var onSiteSelected: (UUID) -> Void

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else {
                #if canImport(UIKit)
                ExploreCatalogMapRepresentable(sites: sites, onSiteSelected: onSiteSelected)
                #else
                Color.clear
                #endif
            }
        }
        .accessibilityLabel("Explore dive sites map")
        .accessibilityHint("Tap a red pin to view dive site details")
        .accessibilityIdentifier("Explore.CatalogMap")
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
