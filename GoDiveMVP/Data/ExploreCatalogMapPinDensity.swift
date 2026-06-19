import Foundation

/// Visible map bounds for Explore catalog pin culling.
struct ExploreCatalogMapViewport: Equatable, Sendable {
    let center: DiveCoordinate
    let latitudeSpan: Double
    let longitudeSpan: Double

    nonisolated init(center: DiveCoordinate, latitudeSpan: Double, longitudeSpan: Double) {
        self.center = center
        self.latitudeSpan = max(latitudeSpan, 0)
        self.longitudeSpan = max(longitudeSpan, 0)
    }

    nonisolated var minLatitude: Double { center.latitude - latitudeSpan / 2 }
    nonisolated var maxLatitude: Double { center.latitude + latitudeSpan / 2 }
    nonisolated var minLongitude: Double { center.longitude - longitudeSpan / 2 }
    nonisolated var maxLongitude: Double { center.longitude + longitudeSpan / 2 }

    nonisolated func contains(_ coordinate: DiveCoordinate) -> Bool {
        guard coordinate.latitude >= minLatitude, coordinate.latitude <= maxLatitude else { return false }
        if minLongitude <= maxLongitude {
            return coordinate.longitude >= minLongitude && coordinate.longitude <= maxLongitude
        }
        return coordinate.longitude >= minLongitude || coordinate.longitude <= maxLongitude
    }
}

/// Zoom-aware Explore pin density for **All sites** — visited pins always render; unvisited pins
/// are spread across the viewport in a grid and revealed gradually while zooming in.
enum ExploreCatalogMapPinDensity: Sendable {
    /// Wider than this latitude span, only the baseline spread grid is used for unvisited pins.
    nonisolated static let sparsePinLatitudeSpan = 140.0
    /// At or below this span, every unvisited site in the viewport may render.
    nonisolated static let fullPinRevealLatitudeSpan = 0.10
    /// Coarsest grid division count when zoomed far out (one unvisited pin per occupied cell).
    nonisolated static let minimumSpreadGridDivisions = 10
    /// Finest grid division count before all unvisited pins are shown.
    nonisolated static let maximumSpreadGridDivisions = 24
    /// Legacy cap used by tests — approximate max unvisited pins at minimum zoom (`minimumSpreadGridDivisions`²).
    nonisolated static let minimumVisiblePinCount = minimumSpreadGridDivisions * minimumSpreadGridDivisions
    /// Zoom progress at which the first spread cell may reveal an unvisited pin (**0** = show full spread grid at default zoom).
    nonisolated static let firstPinRevealProgress = 0.0

    nonisolated static func sitesInViewport(
        _ sites: [ExploreCatalogMapPresentation.PlottedSite],
        viewport: ExploreCatalogMapViewport
    ) -> [ExploreCatalogMapPresentation.PlottedSite] {
        sites.filter { viewport.contains($0.coordinate) }
    }

    nonisolated static func pinZoomProgress(visibleLatitudeSpan: Double) -> Double {
        guard visibleLatitudeSpan < sparsePinLatitudeSpan else { return 0 }
        guard visibleLatitudeSpan > fullPinRevealLatitudeSpan else { return 1 }
        let linear = (sparsePinLatitudeSpan - visibleLatitudeSpan)
            / (sparsePinLatitudeSpan - fullPinRevealLatitudeSpan)
        return min(1, max(0, linear))
    }

    nonisolated static func revealProgress(forRank rank: Int, siteCount: Int) -> Double {
        guard siteCount > 0, rank >= 0 else { return 1 }
        guard siteCount > 1 else { return firstPinRevealProgress }
        guard rank < siteCount else { return 1 }
        let remaining = 1.0 - firstPinRevealProgress
        return firstPinRevealProgress + remaining * Double(rank) / Double(siteCount - 1)
    }

    /// Site IDs that should render as map pins for the current viewport and zoom.
    nonisolated static func visibleSiteIDs(
        sites: [ExploreCatalogMapPresentation.PlottedSite],
        viewport: ExploreCatalogMapViewport
    ) -> Set<UUID> {
        let inViewport = sitesInViewport(sites, viewport: viewport)
        guard !inViewport.isEmpty else { return [] }

        var visible = Set(inViewport.filter(\.isVisited).map(\.id))
        let unvisited = inViewport.filter { !$0.isVisited }
        visible.formUnion(visibleUnvisitedSiteIDs(unvisited, viewport: viewport))
        return visible
    }

    /// Grid-sampled unvisited pins spread across the whole viewport, with more cells filled while zooming in.
    nonisolated static func visibleUnvisitedSiteIDs(
        _ unvisited: [ExploreCatalogMapPresentation.PlottedSite],
        viewport: ExploreCatalogMapViewport
    ) -> Set<UUID> {
        guard !unvisited.isEmpty else { return [] }

        let progress = pinZoomProgress(visibleLatitudeSpan: viewport.latitudeSpan)
        if progress >= 1 || viewport.latitudeSpan <= fullPinRevealLatitudeSpan {
            return Set(unvisited.map(\.id))
        }

        let grid = spreadGridDimensions(viewport: viewport, progress: progress)
        let columns = grid.columns
        let rows = grid.rows

        var sitesByCell: [Int: [ExploreCatalogMapPresentation.PlottedSite]] = [:]
        for site in unvisited {
            let cell = cellIndex(
                for: site.coordinate,
                viewport: viewport,
                columns: columns,
                rows: rows
            )
            sitesByCell[cell, default: []].append(site)
        }

        var winners: [(cellIndex: Int, site: ExploreCatalogMapPresentation.PlottedSite)] = []
        winners.reserveCapacity(sitesByCell.count)

        for (cell, cellSites) in sitesByCell {
            let center = cellCenter(
                for: cell,
                viewport: viewport,
                columns: columns,
                rows: rows
            )
            guard let winner = cellSites.min(by: {
                squaredPlanarDistance(from: $0.coordinate, to: center)
                    < squaredPlanarDistance(from: $1.coordinate, to: center)
            }) else { continue }
            winners.append((cellIndex: cell, site: winner))
        }

        winners.sort { $0.cellIndex < $1.cellIndex }

        var visible = Set<UUID>()
        if firstPinRevealProgress == 0 {
            for winner in winners {
                visible.insert(winner.site.id)
            }
            return visible
        }

        for (rank, winner) in winners.enumerated() {
            guard progress >= revealProgress(forRank: rank, siteCount: winners.count) else { continue }
            visible.insert(winner.site.id)
        }
        return visible
    }

    nonisolated static func spreadGridDimensions(
        viewport: ExploreCatalogMapViewport,
        progress: Double
    ) -> (columns: Int, rows: Int) {
        let minDivisions = minimumSpreadGridDivisions
        let maxDivisions = maximumSpreadGridDivisions
        let divisionCount = minDivisions + Int((Double(maxDivisions - minDivisions) * progress).rounded(.down))

        let latitudeSpan = max(viewport.latitudeSpan, 1e-9)
        let longitudeSpan = max(viewport.longitudeSpan, 1e-9)
        let aspect = longitudeSpan / latitudeSpan

        if aspect >= 1 {
            let columns = divisionCount
            let rows = max(minDivisions, Int((Double(divisionCount) / aspect).rounded(.down)))
            return (columns, rows)
        }

        let rows = divisionCount
        let columns = max(minDivisions, Int((Double(divisionCount) * aspect).rounded(.down)))
        return (columns, rows)
    }

    nonisolated static func cellIndex(
        for coordinate: DiveCoordinate,
        viewport: ExploreCatalogMapViewport,
        columns: Int,
        rows: Int
    ) -> Int {
        let latitudeSpan = max(viewport.latitudeSpan, 1e-9)
        let longitudeSpan = max(viewport.longitudeSpan, 1e-9)
        let latFraction = min(1, max(0, (coordinate.latitude - viewport.minLatitude) / latitudeSpan))
        let lonFraction = min(1, max(0, (coordinate.longitude - viewport.minLongitude) / longitudeSpan))
        let column = min(columns - 1, Int(lonFraction * Double(columns)))
        let row = min(rows - 1, Int(latFraction * Double(rows)))
        return row * columns + column
    }

    nonisolated static func cellCenter(
        for cellIndex: Int,
        viewport: ExploreCatalogMapViewport,
        columns: Int,
        rows: Int
    ) -> DiveCoordinate {
        let row = cellIndex / columns
        let column = cellIndex % columns
        let latitudeSpan = max(viewport.latitudeSpan, 1e-9)
        let longitudeSpan = max(viewport.longitudeSpan, 1e-9)
        let latFraction = (Double(row) + 0.5) / Double(rows)
        let lonFraction = (Double(column) + 0.5) / Double(columns)
        return DiveCoordinate(
            latitude: viewport.minLatitude + latFraction * latitudeSpan,
            longitude: viewport.minLongitude + lonFraction * longitudeSpan
        )
    }

    nonisolated static func squaredPlanarDistance(from coordinate: DiveCoordinate, to center: DiveCoordinate) -> Double {
        let deltaLatitude = coordinate.latitude - center.latitude
        let deltaLongitude = coordinate.longitude - center.longitude
        return deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude
    }
}
