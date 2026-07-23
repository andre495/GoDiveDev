import Foundation
import SwiftData

/// Persists and reads timezone data on catalog **`DiveSite`** rows (DST-aware via IANA identifier when known).
enum DiveSiteTimeZoneResolution: Sendable {

    /// Seconds east of UTC at **`instant`**, using persisted site fields when set.
    nonisolated static func offsetSeconds(for site: DiveSite, at instant: Date) -> Int? {
        if let identifier = normalizedIdentifier(site.timeZoneIdentifier),
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone.secondsFromGMT(for: instant)
        }
        return site.timeZoneOffsetSeconds
    }

    /// Same as `offsetSeconds(for: DiveSite, at:)` for a user-owned **`UserDiveSite`**.
    nonisolated static func offsetSeconds(for site: UserDiveSite, at instant: Date) -> Int? {
        if let identifier = normalizedIdentifier(site.timeZoneIdentifier),
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone.secondsFromGMT(for: instant)
        }
        return site.timeZoneOffsetSeconds
    }

    /// Same as `offsetSeconds(for: DiveSite, at:)` for a resolved catalog/user site (**`DiveLinkedSiteResolver`**).
    nonisolated static func offsetSeconds(for site: DiveLinkedSiteResolver.ResolvedSite, at instant: Date) -> Int? {
        if let identifier = normalizedIdentifier(site.timeZoneIdentifier),
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone.secondsFromGMT(for: instant)
        }
        return site.timeZoneOffsetSeconds
    }

    /// UDDF hours-from-UTC when the catalog site already has persisted timezone data.
    nonisolated static func uddfHoursIfPersisted(from site: DiveSite, at instant: Date) -> Double? {
        guard let offsetSeconds = offsetSeconds(for: site, at: instant) else { return nil }
        return Double(offsetSeconds) / 3600.0
    }

    /// Reverse-geocodes site geography when timezone is missing; writes **`timeZoneIdentifier`** + **`timeZoneOffsetSeconds`**.
    @MainActor
    static func ensureResolved(
        for site: DiveSite,
        at referenceInstant: Date,
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard offsetSeconds(for: site, at: referenceInstant) == nil else { return }

        if let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            let input = DiveGeographicTimeZoneLookup.CoordinateInput(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            if let timeZone = await resolver.timeZone(for: input) {
                persist(timeZone, on: site, at: referenceInstant)
                return
            }
        }

        if let query = locationQuery(for: site),
           let timeZone = await resolver.timeZone(forLocationQuery: query) {
            persist(timeZone, on: site, at: referenceInstant)
        }
    }

    /// Same as `ensureResolved(for: DiveSite, ...)` for a user-owned **`UserDiveSite`**.
    @MainActor
    static func ensureResolved(
        for site: UserDiveSite,
        at referenceInstant: Date,
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard offsetSeconds(for: site, at: referenceInstant) == nil else { return }

        if let coordinate = DiveMapCoordinateResolver.coordinate(from: site),
           DiveMapCoordinateResolver.isUsable(coordinate) {
            let input = DiveGeographicTimeZoneLookup.CoordinateInput(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            if let timeZone = await resolver.timeZone(for: input) {
                persist(timeZone, on: site, at: referenceInstant)
                return
            }
        }

        if let query = locationQuery(for: site),
           let timeZone = await resolver.timeZone(forLocationQuery: query) {
            persist(timeZone, on: site, at: referenceInstant)
        }
    }

    /// Resolves the linked catalog/user site for each activity (via **`diveSiteID`**) and persists timezone data.
    @MainActor
    static func ensureResolvedForLinkedActivities(
        _ activities: [DiveActivity],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        var resolvedSiteIDs: Set<UUID> = []
        for activity in activities {
            guard let diveSiteID = activity.diveSiteID, let modelContext = activity.modelContext else { continue }
            guard resolvedSiteIDs.insert(diveSiteID).inserted else { continue }
            if let userSite = try? DiveLinkedSiteResolver.existingUserDiveSite(id: diveSiteID, modelContext: modelContext) {
                await ensureResolved(for: userSite, at: activity.startTime, resolver: resolver)
            } else if let catalogSite = try? DiveLinkedSiteResolver.existingCatalogDiveSite(id: diveSiteID, modelContext: modelContext) {
                await ensureResolved(for: catalogSite, at: activity.startTime, resolver: resolver)
            }
            await Task.yield()
        }
    }

    @MainActor
    static func ensureResolvedForLinkedSnorkelActivities(
        _ activities: [SnorkelActivity],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        var resolvedSiteIDs: Set<UUID> = []
        for activity in activities {
            guard let diveSiteID = activity.diveSiteID, let modelContext = activity.modelContext else { continue }
            guard resolvedSiteIDs.insert(diveSiteID).inserted else { continue }
            if let userSite = try? DiveLinkedSiteResolver.existingUserDiveSite(id: diveSiteID, modelContext: modelContext) {
                await ensureResolved(for: userSite, at: activity.startTime, resolver: resolver)
            } else if let catalogSite = try? DiveLinkedSiteResolver.existingCatalogDiveSite(id: diveSiteID, modelContext: modelContext) {
                await ensureResolved(for: catalogSite, at: activity.startTime, resolver: resolver)
            }
            await Task.yield()
        }
    }

    nonisolated static func persist(_ timeZone: TimeZone, on site: DiveSite, at instant: Date) {
        site.timeZoneIdentifier = timeZone.identifier
        site.timeZoneOffsetSeconds = timeZone.secondsFromGMT(for: instant)
    }

    /// Same as `persist(_:on: DiveSite, at:)` for a user-owned **`UserDiveSite`**.
    nonisolated static func persist(_ timeZone: TimeZone, on site: UserDiveSite, at instant: Date) {
        site.timeZoneIdentifier = timeZone.identifier
        site.timeZoneOffsetSeconds = timeZone.secondsFromGMT(for: instant)
    }

    nonisolated static func locationQuery(for site: DiveSite) -> String? {
        let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (region.isEmpty, country.isEmpty) {
        case (false, false):
            return "\(region), \(country)"
        case (false, true):
            return region
        case (true, false):
            return country
        case (true, true):
            break
        }
        let name = site.siteName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Same as `locationQuery(for: DiveSite)` for a user-owned **`UserDiveSite`**.
    nonisolated static func locationQuery(for site: UserDiveSite) -> String? {
        let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = site.country.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (region.isEmpty, country.isEmpty) {
        case (false, false):
            return "\(region), \(country)"
        case (false, true):
            return region
        case (true, false):
            return country
        case (true, true):
            break
        }
        let name = site.siteName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private nonisolated static func normalizedIdentifier(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
