import Foundation

/// Whether Explore map pins show progressive zoom labels or stay unlabeled.
enum ExploreCatalogMapPinLabelPolicy: Equatable, Sendable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.progressiveZoomReveal, .progressiveZoomReveal),
             (.pinOnlyAlways, .pinOnlyAlways):
            return true
        default:
            return false
        }
    }

    /// Logbook scope — labels appear gradually while zooming in.
    case progressiveZoomReveal
    /// All-sites scope — pins never show on-map name labels.
    case pinOnlyAlways

    nonisolated static func policy(for scope: ExploreSiteScope) -> Self {
        switch scope {
        case .logbook:
            return .progressiveZoomReveal
        case .allSites:
            return .pinOnlyAlways
        }
    }

    nonisolated static func usesPinCallout(for scope: ExploreSiteScope) -> Bool {
        _ = scope
        return true
    }

    nonisolated func labeledSiteIDs(
        sites: [ExploreCatalogMapPresentation.PlottedSite],
        visibleLatitudeSpan: Double,
        mapCenter: DiveCoordinate
    ) -> Set<UUID> {
        switch self {
        case .pinOnlyAlways:
            return []
        case .progressiveZoomReveal:
            return ExploreCatalogMapLabelVisibility.labeledSiteIDs(
                sites: sites,
                visibleLatitudeSpan: visibleLatitudeSpan,
                mapCenter: mapCenter
            )
        }
    }

    nonisolated func visibleSiteIDs(
        sites: [ExploreCatalogMapPresentation.PlottedSite],
        viewport: ExploreCatalogMapViewport
    ) -> Set<UUID> {
        switch self {
        case .progressiveZoomReveal:
            return Set(sites.map(\.id))
        case .pinOnlyAlways:
            return ExploreCatalogMapPinDensity.visibleSiteIDs(
                sites: sites,
                viewport: viewport
            )
        }
    }

    nonisolated var usesDynamicPinDensity: Bool {
        self == .pinOnlyAlways
    }
}
