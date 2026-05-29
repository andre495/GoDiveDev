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

    /// UDDF hours-from-UTC for a dive site: **network reverse geocode** (or location search) first, offline regions last.
    @MainActor
    static func uddfHoursFromSite(
        latitude: Double?,
        longitude: Double?,
        locationName: String?,
        catalogSite: DiveSite? = nil,
        at instant: Date,
        resolver: any GeocodingTimeZoneResolving
    ) async -> Double? {
        if let catalogSite {
            if let persisted = DiveSiteTimeZoneResolution.uddfHoursIfPersisted(from: catalogSite, at: instant) {
                return persisted
            }
            await DiveSiteTimeZoneResolution.ensureResolved(
                for: catalogSite,
                at: instant,
                resolver: resolver
            )
            if let persisted = DiveSiteTimeZoneResolution.uddfHoursIfPersisted(from: catalogSite, at: instant) {
                return persisted
            }
        }

        if let latitude, let longitude {
            let input = CoordinateInput(latitude: latitude, longitude: longitude)
            if let timeZone = await resolver.timeZone(for: input) {
                if let catalogSite {
                    DiveSiteTimeZoneResolution.persist(timeZone, on: catalogSite, at: instant)
                }
                return uddfHours(from: timeZone, at: instant)
            }
            if let offline = DiveSiteGeographyTimeZoneInference.uddfHoursFromUTC(
                latitude: latitude,
                longitude: longitude,
                at: instant
            ) {
                return offline
            }
        }

        let trimmedLocation = locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLocation.isEmpty,
           let timeZone = await resolver.timeZone(forLocationQuery: trimmedLocation) {
            if let catalogSite {
                DiveSiteTimeZoneResolution.persist(timeZone, on: catalogSite, at: instant)
            }
            return uddfHours(from: timeZone, at: instant)
        }

        return DiveSiteGeographyTimeZoneInference.uddfHoursFromLocationName(locationName, at: instant)
    }

    private static func uddfHours(from timeZone: TimeZone, at instant: Date) -> Double {
        Double(timeZone.secondsFromGMT(for: instant)) / 3600.0
    }
}

/// Reverse-geocodes coordinates to **`TimeZone`** (network; cached per rounded lat/lon).
@MainActor
protocol GeocodingTimeZoneResolving {
    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone?
    func timeZone(forLocationQuery query: String) async -> TimeZone?
}

extension GeocodingTimeZoneResolving {
    func timeZone(forLocationQuery query: String) async -> TimeZone? { nil }
}

/// Shared **`MKReverseGeocodingRequest`** / **`MKLocalSearch`** resolver with an in-memory cache (bulk import friendly).
@MainActor
final class MapKitGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {

    static let shared = MapKitGeocodingTimeZoneResolver()

    private var coordinateCache: [String: TimeZone] = [:]
    private var locationQueryCache: [String: TimeZone] = [:]

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        let key = coordinateCacheKey(for: coordinate)
        if let cached = coordinateCache[key] {
            return cached
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        do {
            let mapItems = try await request.mapItems
            guard let timeZone = mapItems.first?.timeZone else { return nil }
            coordinateCache[key] = timeZone
            return timeZone
        } catch {
            return nil
        }
    }

    func timeZone(forLocationQuery query: String) async -> TimeZone? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let key = trimmed.lowercased()
        if let cached = locationQueryCache[key] {
            return cached
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let timeZone = response.mapItems.first?.timeZone else { return nil }
            locationQueryCache[key] = timeZone
            return timeZone
        } catch {
            return nil
        }
    }

    private func coordinateCacheKey(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }
}
