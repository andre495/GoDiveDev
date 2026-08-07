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
        let engine = GoDiveMapEngine.active
        let hasGoogleKey = GoogleMapsBootstrap.loadAPIKey() != nil
        let _ = Self.logBodyIfNeeded(
            sitesCount: sites.count,
            siteScope: siteScope,
            engine: engine,
            hasGoogleKey: hasGoogleKey,
            signature: sitesChangeSignature
        )
        return Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else if engine == .googleMaps, hasGoogleKey {
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

    nonisolated private static let bodyLogLock = NSLock()
    nonisolated(unsafe) private static var lastLoggedSignature: String?

    nonisolated private static func logBodyIfNeeded(
        sitesCount: Int,
        siteScope: ExploreSiteScope,
        engine: GoDiveMapEngine,
        hasGoogleKey: Bool,
        signature: String
    ) {
        bodyLogLock.lock()
        let shouldLog = lastLoggedSignature != signature
        if shouldLog { lastLoggedSignature = signature }
        bodyLogLock.unlock()
        guard shouldLog else { return }
        ExplorePinsDiagnostics.note(
            "mapView body sites=\(sitesCount) scope=\(siteScope) engine=\(engine.rawValue) googleKey=\(hasGoogleKey) signature=\(signature)"
        )
    }
}

/// Brief stand-in while All Sites pins seed — avoids mounting an empty map that then recenters.
struct ExploreCatalogMapLoadingPlaceholder: View {
    var body: some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                ProgressView()
                    .tint(AppTheme.Colors.tabUnselected)
            }
            .accessibilityLabel("Loading dive sites map")
            .accessibilityIdentifier("Explore.CatalogMap.Loading")
    }
}
