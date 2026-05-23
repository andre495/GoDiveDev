import CoreLocation
import Foundation
import MapKit

/// Resolves an IANA timezone at map coordinates, then a DST-aware offset at a given instant.
enum DiveGeographicTimeZoneLookup: Sendable {

    struct CoordinateInput: Equatable, Sendable {
        var latitude: Double
        var longitude: Double
    }

    /// Seconds east of UTC at **`instant`** for the timezone at **`coordinate`**, or **`nil`** when lookup fails.
    @MainActor
    static func offsetSeconds(
        for coordinate: CoordinateInput,
        at instant: Date,
        resolver: any GeocodingTimeZoneResolving
    ) async -> Int? {
        guard let timeZone = await resolver.timeZone(for: coordinate) else { return nil }
        return timeZone.secondsFromGMT(for: instant)
    }
}

/// Reverse-geocodes coordinates to **`TimeZone`** (network; cached per rounded lat/lon).
@MainActor
protocol GeocodingTimeZoneResolving {
    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone?
}

/// Shared **`MKReverseGeocodingRequest`** resolver with an in-memory cache (bulk import friendly).
@MainActor
final class MapKitGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {

    static let shared = MapKitGeocodingTimeZoneResolver()

    private var cache: [String: TimeZone] = [:]

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        let key = cacheKey(for: coordinate)
        if let cached = cache[key] {
            return cached
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        do {
            let mapItems = try await request.mapItems
            guard let timeZone = mapItems.first?.timeZone else { return nil }
            cache[key] = timeZone
            return timeZone
        } catch {
            return nil
        }
    }

    private func cacheKey(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }
}
