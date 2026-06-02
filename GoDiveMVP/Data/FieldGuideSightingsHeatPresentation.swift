import CoreLocation
import Foundation
import MapKit

/// Field Guide **Sightings** tab — aggregate owner sightings into regional heat cells for MapKit.
enum FieldGuideSightingsHeatPresentation: Sendable {

    struct SightingPlotInput: Sendable, Equatable {
        let sightingUUID: String
        let marineLifeUUID: String
        let diveActivityID: UUID?
        let diveSiteID: UUID?
    }

    struct DiveSiteLocationSnapshot: Sendable, Equatable {
        let id: UUID
        let latitude: Double?
        let longitude: Double?
        let region: String
        let country: String
    }

    struct PlottedSighting: Sendable, Equatable {
        let sightingUUID: String
        let marineLifeUUID: String
        let coordinate: DiveCoordinate
        let regionLabel: String
    }

    struct HeatRegionCell: Sendable, Identifiable, Equatable {
        var id: String { regionKey }
        let regionKey: String
        let regionLabel: String
        let center: DiveCoordinate
        let sightingCount: Int
        /// 0…1 relative to the busiest region in the current set.
        let normalizedIntensity: Double
        /// MapKit circle radius in meters.
        let radiusMeters: CLLocationDistance
    }

    struct OverviewData: Sendable, Equatable {
        let totalSightings: Int
        let plottableSightings: Int
        let uniqueSpeciesCount: Int
        let regionCount: Int
        let heatCells: [HeatRegionCell]
        let topRegionLabel: String?
        let topRegionCount: Int
    }

    /// Caribbean-centered fallback when there is nothing to fit yet.
    nonisolated static let defaultMapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 18.5, longitude: -75.5),
        span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 38)
    )

    nonisolated static func overviewData(
        sightings: [SightingPlotInput],
        diveSitesByID: [UUID: DiveSiteLocationSnapshot],
        ownerActivityIDs: Set<UUID>
    ) -> OverviewData {
        let ownerSightings = sightings.filter { sighting in
            guard let diveActivityID = sighting.diveActivityID else { return false }
            return ownerActivityIDs.contains(diveActivityID)
        }

        let plotted = plottableSightings(from: ownerSightings, diveSitesByID: diveSitesByID)
        let heatCells = heatRegions(from: plotted)
        let topRegion = heatCells.max(by: { $0.sightingCount < $1.sightingCount })

        return OverviewData(
            totalSightings: ownerSightings.count,
            plottableSightings: plotted.count,
            uniqueSpeciesCount: Set(plotted.map(\.marineLifeUUID)).count,
            regionCount: heatCells.count,
            heatCells: heatCells,
            topRegionLabel: topRegion?.regionLabel,
            topRegionCount: topRegion?.sightingCount ?? 0
        )
    }

    nonisolated static func mapRegion(for cells: [HeatRegionCell]) -> MKCoordinateRegion {
        guard let first = cells.first else { return defaultMapRegion }
        guard cells.count > 1 else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: first.center.latitude,
                    longitude: first.center.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: max(first.radiusMeters / 111_000 * 4, 0.8),
                    longitudeDelta: max(first.radiusMeters / 111_000 * 4, 0.8)
                )
            )
        }

        var minLat = first.center.latitude
        var maxLat = first.center.latitude
        var minLon = first.center.longitude
        var maxLon = first.center.longitude

        for cell in cells.dropFirst() {
            minLat = min(minLat, cell.center.latitude)
            maxLat = max(maxLat, cell.center.latitude)
            minLon = min(minLon, cell.center.longitude)
            maxLon = max(maxLon, cell.center.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = max((maxLat - minLat) * 1.55, 1.2)
        let lonDelta = max((maxLon - minLon) * 1.55, 1.2)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    nonisolated static func regionLabel(country: String, region: String) -> String {
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRegion.isEmpty, trimmedCountry.isEmpty { return "Unknown region" }
        if trimmedRegion.isEmpty { return trimmedCountry }
        if trimmedCountry.isEmpty { return trimmedRegion }
        return "\(trimmedRegion), \(trimmedCountry)"
    }

    nonisolated static func plottableSightings(
        from sightings: [SightingPlotInput],
        diveSitesByID: [UUID: DiveSiteLocationSnapshot]
    ) -> [PlottedSighting] {
        sightings.compactMap { sighting in
            guard let siteID = sighting.diveSiteID,
                  let site = diveSitesByID[siteID],
                  let coordinate = coordinate(from: site)
            else { return nil }

            return PlottedSighting(
                sightingUUID: sighting.sightingUUID,
                marineLifeUUID: sighting.marineLifeUUID,
                coordinate: coordinate,
                regionLabel: regionLabel(country: site.country, region: site.region)
            )
        }
    }

    nonisolated static func heatRegions(from plotted: [PlottedSighting]) -> [HeatRegionCell] {
        guard !plotted.isEmpty else { return [] }

        var grouped: [String: [PlottedSighting]] = [:]
        for sighting in plotted {
            let key = normalizedRegionKey(sighting.regionLabel)
            grouped[key, default: []].append(sighting)
        }

        let maxCount = grouped.values.map(\.count).max() ?? 1
        return grouped.map { regionKey, group in
            let center = centroid(of: group.map(\.coordinate))
            let count = group.count
            let intensity = Double(count) / Double(maxCount)
            return HeatRegionCell(
                regionKey: regionKey,
                regionLabel: group[0].regionLabel,
                center: center,
                sightingCount: count,
                normalizedIntensity: intensity,
                radiusMeters: radiusMeters(for: count, maxCount: maxCount)
            )
        }
        .sorted { lhs, rhs in
            if lhs.sightingCount != rhs.sightingCount {
                return lhs.sightingCount > rhs.sightingCount
            }
            return lhs.regionLabel.localizedCaseInsensitiveCompare(rhs.regionLabel) == .orderedAscending
        }
    }

    nonisolated static func radiusMeters(for count: Int, maxCount: Int) -> CLLocationDistance {
        let normalized = Double(count) / Double(max(maxCount, 1))
        return 45_000 + normalized * 110_000
    }

    nonisolated static func heatFillColor(intensity: Double) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let clamped = min(max(intensity, 0), 1)
        if clamped < 0.5 {
            let t = clamped / 0.5
            return (
                red: CGFloat(0.12 + t * 0.55),
                green: CGFloat(0.62 + t * 0.08),
                blue: CGFloat(0.72 - t * 0.38)
            )
        }
        let t = (clamped - 0.5) / 0.5
        return (
            red: CGFloat(0.67 + t * 0.28),
            green: CGFloat(0.70 - t * 0.42),
            blue: CGFloat(0.34 - t * 0.22)
        )
    }

    private nonisolated static func coordinate(from site: DiveSiteLocationSnapshot) -> DiveCoordinate? {
        guard let lat = site.latitude, let lon = site.longitude else { return nil }
        let candidate = DiveCoordinate(latitude: lat, longitude: lon)
        return DiveMapCoordinateResolver.isUsable(candidate) ? candidate : nil
    }

    private nonisolated static func normalizedRegionKey(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private nonisolated static func centroid(of coordinates: [DiveCoordinate]) -> DiveCoordinate {
        let latSum = coordinates.reduce(0.0) { $0 + $1.latitude }
        let lonSum = coordinates.reduce(0.0) { $0 + $1.longitude }
        let count = Double(coordinates.count)
        return DiveCoordinate(latitude: latSum / count, longitude: lonSum / count)
    }
}
