import Foundation

/// Programmatic pushes from **`TripDetailView`** (stat tile, media gallery). Map pins use **`openCatalogDiveSiteDetail`**.
enum TripDetailNavigationTarget: Hashable {
    case linkedDive(UUID)
    case diveMedia(diveID: UUID, mediaID: UUID)

    init?(mediaNavigation target: TripDetailMediaNavigationTarget) {
        self = .diveMedia(diveID: target.diveID, mediaID: target.mediaID)
    }
}

enum TripDetailDiveSiteNavigation: Sendable {
    nonisolated static func resolvedSite(
        siteID: UUID,
        plannedSites: [DiveSite],
        catalogSites: [DiveSite]
    ) -> DiveSite? {
        if let planned = plannedSites.first(where: { $0.id == siteID }) {
            return planned
        }
        return catalogSites.first(where: { $0.id == siteID })
    }
}
