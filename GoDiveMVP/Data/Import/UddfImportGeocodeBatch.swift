import Foundation

/// Dedupes MapKit timezone lookups for bulk UDDF import, then warms the shared resolver cache in parallel.
enum UddfImportGeocodeBatch: Sendable {

    /// Unique lookup work for one import batch (coordinates rounded like the MapKit resolver cache).
    struct LookupKey: Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            case coordinate(cacheKey: String)
            case locationQuery(normalized: String)
        }

        var kind: Kind
    }

    /// Max concurrent MapKit reverse-geocode / local-search calls while warming the cache.
    nonisolated static let maxConcurrentLookups = 4

    /// Collects distinct coordinate + location-query keys used by MacDive datetime normalization.
    @MainActor
    static func collectLookupKeys(
        from activities: [DiveActivity],
        catalogSites: [DiveSite] = []
    ) -> Set<LookupKey> {
        var keys = Set<LookupKey>()
        for activity in activities where activity.source == .macDive {
            if let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
                on: activity,
                catalogSites: catalogSites
            ) {
                keys.insert(
                    LookupKey(kind: .coordinate(cacheKey: coordinateCacheKey(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )))
                )
            }
            if let label = DiveActivityTimeZoneResolution.locationLabelForLookup(
                on: activity,
                catalogSites: catalogSites
            ) {
                let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !normalized.isEmpty {
                    keys.insert(LookupKey(kind: .locationQuery(normalized: normalized)))
                }
            }
        }
        return keys
    }

    /// Resolves each unique key once (parallel, capped concurrency) so later sequential normalize passes hit cache.
    @MainActor
    static func prefetchTimeZones(
        for keys: Set<LookupKey>,
        resolver: any GeocodingTimeZoneResolving,
        maxConcurrent: Int = maxConcurrentLookups
    ) async {
        guard !keys.isEmpty else { return }
        let keyList = Array(keys)
        let concurrency = max(1, maxConcurrent)
        var nextIndex = 0

        await withTaskGroup(of: Void.self) { group in
            func enqueueNext() {
                guard nextIndex < keyList.count else { return }
                let key = keyList[nextIndex]
                nextIndex += 1
                group.addTask { @MainActor in
                    switch key.kind {
                    case .coordinate(let cacheKey):
                        let parts = cacheKey.split(separator: ",")
                        guard parts.count == 2,
                              let lat = Double(parts[0]),
                              let lon = Double(parts[1])
                        else { return }
                        _ = await resolver.timeZone(
                            for: DiveGeographicTimeZoneLookup.CoordinateInput(
                                latitude: lat,
                                longitude: lon
                            )
                        )
                    case .locationQuery(let normalized):
                        _ = await resolver.timeZone(forLocationQuery: normalized)
                    }
                }
            }

            for _ in 0..<min(concurrency, keyList.count) {
                enqueueNext()
            }
            for await _ in group {
                enqueueNext()
            }
        }
    }

    /// Collect + prefetch in one call (bulk import entry point).
    @MainActor
    static func prefetchForActivities(
        _ activities: [DiveActivity],
        catalogSites: [DiveSite] = [],
        resolver: (any GeocodingTimeZoneResolving)? = nil
    ) async {
        let keys = collectLookupKeys(from: activities, catalogSites: catalogSites)
        await prefetchTimeZones(
            for: keys,
            resolver: resolver ?? MapKitGeocodingTimeZoneResolver.shared
        )
    }

    /// Network hours-from-UTC (MainActor MapKit; safe to `await` from import normalize).
    @MainActor
    static func uddfHoursFromNetwork(
        latitude: Double?,
        longitude: Double?,
        locationName: String?,
        at instant: Date,
        resolver: any GeocodingTimeZoneResolving
    ) async -> Double? {
        await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            catalogSite: nil,
            at: instant,
            resolver: resolver
        )
    }

    nonisolated static func coordinateCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.3f,%.3f", latitude, longitude)
    }
}
