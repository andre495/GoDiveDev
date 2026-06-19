import Foundation

/// Keeps Explore **All sites** pins on screen while panning; culls only when zooming back out.
enum ExploreCatalogMapStickyPinVisibility: Sendable {
    struct State: Equatable, Sendable {
        var revealedUnvisitedSiteIDs: Set<UUID> = []
        var lastZoomProgress: Double?

        nonisolated init(
            revealedUnvisitedSiteIDs: Set<UUID> = [],
            lastZoomProgress: Double? = nil
        ) {
            self.revealedUnvisitedSiteIDs = revealedUnvisitedSiteIDs
            self.lastZoomProgress = lastZoomProgress
        }
    }

    private nonisolated static let zoomOutProgressEpsilon = 0.012

    /// Merges density-eligible pins with previously revealed unvisited pins for stable panning.
    nonisolated static func visibleSiteIDs(
        sites: [ExploreCatalogMapPresentation.PlottedSite],
        viewport: ExploreCatalogMapViewport,
        freshEligible: Set<UUID>,
        state: inout State
    ) -> Set<UUID> {
        let inViewport = ExploreCatalogMapPinDensity.sitesInViewport(sites, viewport: viewport)
        let inViewportIDs = Set(inViewport.map(\.id))
        let visitedInViewport = Set(inViewport.filter(\.isVisited).map(\.id))
        let freshUnvisited = freshEligible.subtracting(visitedInViewport)

        let progress = ExploreCatalogMapPinDensity.pinZoomProgress(
            visibleLatitudeSpan: viewport.latitudeSpan
        )
        let zoomedOut = state.lastZoomProgress.map { progress + zoomOutProgressEpsilon < $0 } ?? false

        var stickyUnvisited = state.revealedUnvisitedSiteIDs
        if zoomedOut {
            stickyUnvisited = stickyUnvisited.intersection(freshUnvisited)
        } else {
            stickyUnvisited = stickyUnvisited.intersection(inViewportIDs)
        }
        stickyUnvisited.formUnion(freshUnvisited)

        state.revealedUnvisitedSiteIDs = stickyUnvisited
        state.lastZoomProgress = progress

        return visitedInViewport.union(stickyUnvisited)
    }

    nonisolated static func reset(_ state: inout State) {
        state = State()
    }
}
