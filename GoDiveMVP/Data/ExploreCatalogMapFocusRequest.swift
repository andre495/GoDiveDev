import Foundation

/// Command for the Explore map to zoom to a site and reveal its callout.
struct ExploreCatalogMapFocusRequest: Equatable, Sendable {
    let selection: ExploreMapSiteSelection
    let coordinate: DiveCoordinate
    let requestID: UUID
}
