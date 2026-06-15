import Foundation

/// Zoom-aware Explore pin labels — wider map views show fewer site names; each site reveals individually while zooming in.
enum ExploreCatalogMapLabelVisibility: Sendable {
    /// Above this visible latitude span, pins render without name labels.
    nonisolated static let pinOnlyLatitudeSpan = 7.5
    /// At or below this span, every plotted site may show a label.
    nonisolated static let allLabelsLatitudeSpan = 0.06
    /// Zoom progress at which the nearest site (rank 0) may show a label.
    nonisolated static let firstLabelRevealProgress = 0.32

    /// Normalized zoom-in progress **0…1** (0 = pin-only, 1 = all labels allowed).
    nonisolated static func zoomProgress(visibleLatitudeSpan: Double) -> Double {
        guard visibleLatitudeSpan < pinOnlyLatitudeSpan else { return 0 }
        guard visibleLatitudeSpan > allLabelsLatitudeSpan else { return 1 }
        let linear = (pinOnlyLatitudeSpan - visibleLatitudeSpan)
            / (pinOnlyLatitudeSpan - allLabelsLatitudeSpan)
        return smoothstep(linear)
    }

    /// How many site labels may appear for the current zoom level.
    nonisolated static func maximumLabelCount(visibleLatitudeSpan: Double, siteCount: Int) -> Int {
        guard siteCount > 0 else { return 0 }
        let progress = zoomProgress(visibleLatitudeSpan: visibleLatitudeSpan)
        guard progress > 0 else { return 0 }
        var count = 0
        for rank in 0..<siteCount where progress >= revealProgress(forRank: rank, siteCount: siteCount) {
            count += 1
        }
        return count
    }

    /// Progress **0…1** at which the site at **`rank`** (0 = nearest to center) earns a label.
    nonisolated static func revealProgress(forRank rank: Int, siteCount: Int) -> Double {
        guard siteCount > 0, rank >= 0 else { return 1 }
        guard siteCount > 1 else { return firstLabelRevealProgress }
        guard rank < siteCount else { return 1 }
        let remaining = 1.0 - firstLabelRevealProgress
        return firstLabelRevealProgress + remaining * Double(rank) / Double(siteCount - 1)
    }

    /// Site IDs that should show a name label; nearest sites reveal first, one-by-one as zoom progress increases.
    nonisolated static func labeledSiteIDs(
        sites: [ExploreCatalogMapPresentation.PlottedSite],
        visibleLatitudeSpan: Double,
        mapCenter: DiveCoordinate
    ) -> Set<UUID> {
        labeledIDs(
            items: sites.map { (id: $0.id, coordinate: $0.coordinate) },
            visibleLatitudeSpan: visibleLatitudeSpan,
            mapCenter: mapCenter
        )
    }

    /// Trip overview pins use the same zoom-aware label rules as Explore.
    nonisolated static func labeledTripPinIDs(
        pins: [TripDetailMapPin],
        visibleLatitudeSpan: Double,
        mapCenter: DiveCoordinate
    ) -> Set<String> {
        labeledIDs(
            items: pins.map { (id: $0.id, coordinate: $0.coordinate) },
            visibleLatitudeSpan: visibleLatitudeSpan,
            mapCenter: mapCenter
        )
    }

    nonisolated static func labeledIDs<ID: Hashable>(
        items: [(id: ID, coordinate: DiveCoordinate)],
        visibleLatitudeSpan: Double,
        mapCenter: DiveCoordinate
    ) -> Set<ID> {
        let progress = zoomProgress(visibleLatitudeSpan: visibleLatitudeSpan)
        guard progress > 0, !items.isEmpty else { return [] }

        let ranked = items.sorted {
            squaredPlanarDistance(from: $0.coordinate, to: mapCenter)
                < squaredPlanarDistance(from: $1.coordinate, to: mapCenter)
        }

        var labeled = Set<ID>()
        for (rank, item) in ranked.enumerated() {
            if progress >= revealProgress(forRank: rank, siteCount: items.count) {
                labeled.insert(item.id)
            }
        }
        return labeled
    }

    nonisolated static func squaredPlanarDistance(from coordinate: DiveCoordinate, to center: DiveCoordinate) -> Double {
        let deltaLatitude = coordinate.latitude - center.latitude
        let deltaLongitude = coordinate.longitude - center.longitude
        return deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude
    }

    /// Hermite smoothstep for gradual mid-zoom changes.
    nonisolated static func smoothstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}
