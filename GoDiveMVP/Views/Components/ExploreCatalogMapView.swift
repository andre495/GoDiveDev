import SwiftUI

/// Full-bleed **Explore** map with catalog dive-site pins.
struct ExploreCatalogMapView: View {
    let sites: [ExploreCatalogMapPresentation.PlottedSite]
    let sitesChangeSignature: String
    let siteScope: ExploreSiteScope
    var focusRequest: ExploreCatalogMapFocusRequest?
    var onSiteSelected: (ExploreMapSiteSelection) -> Void

    private var pinLabelPolicy: ExploreCatalogMapPinLabelPolicy {
        ExploreCatalogMapPinLabelPolicy.policy(for: siteScope)
    }

    private var usesPinCallout: Bool {
        ExploreCatalogMapPinLabelPolicy.usesPinCallout(for: siteScope)
    }

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else if GoDiveMapEngine.active == .googleMaps, GoogleMapsBootstrap.loadAPIKey() != nil {
                #if canImport(UIKit)
                ExploreCatalogGoogleMapRepresentable(
                    sites: sites,
                    sitesChangeSignature: sitesChangeSignature,
                    pinLabelPolicy: pinLabelPolicy,
                    usesPinCallout: usesPinCallout,
                    focusRequest: focusRequest,
                    onSiteSelected: onSiteSelected
                )
                #else
                Color.clear
                #endif
            } else {
                #if canImport(UIKit)
                ExploreCatalogMapRepresentable(
                    sites: sites,
                    sitesChangeSignature: sitesChangeSignature,
                    pinLabelPolicy: pinLabelPolicy,
                    usesPinCallout: usesPinCallout,
                    focusRequest: focusRequest,
                    onSiteSelected: onSiteSelected
                )
                #else
                Color.clear
                #endif
            }
        }
        .accessibilityLabel("Explore dive sites map")
        .accessibilityHint("Tap a site marker to preview its name, then open details from the callout")
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
