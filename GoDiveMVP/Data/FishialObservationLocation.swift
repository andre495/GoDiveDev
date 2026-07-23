import Foundation

/// Resolves dive coordinates for Fishial's **`Fishial-Location-Lat-Lon`** recognition header.
enum FishialObservationLocation: Sendable {

    nonisolated static func resolvedCoordinate(
        for dive: DiveActivity,
        catalogSites: [DiveSite]
    ) -> DiveCoordinate? {
        dive.resolvedMapCoordinate(catalogSites: catalogSites)
    }

    nonisolated static func resolvedCoordinate(
        for snorkel: SnorkelActivity,
        catalogSites: [DiveSite]
    ) -> DiveCoordinate? {
        snorkel.resolvedMapCoordinate(catalogSites: catalogSites)
    }

    /// Fishial expects decimal degrees as **`latitude, longitude`** (see API reference).
    nonisolated static func locationHeaderValue(for coordinate: DiveCoordinate) -> String {
        String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude)
    }
}
