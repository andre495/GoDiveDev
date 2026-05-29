import Foundation

/// Fills **`DiveActivity.timeZoneOffsetSeconds`** from dive GPS / linked site coordinates when import did not supply an offset.
enum DiveActivityTimeZoneResolution {

    /// Best coordinate for timezone lookup: **preview-matched catalog site**, entry GPS, then linked site.
    static func coordinateForLookup(
        on activity: DiveActivity,
        catalogSites: [DiveSite] = []
    ) -> DiveCoordinate? {
        if let matched = DiveActivitySiteAssociation.previewBestMatch(for: activity, catalogSites: catalogSites),
           let catalogCoordinate = DiveMapCoordinateResolver.coordinate(from: matched),
           DiveMapCoordinateResolver.isUsable(catalogCoordinate) {
            return catalogCoordinate
        }
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return entry
        }
        if let site = activity.siteCoordinate, DiveMapCoordinateResolver.isUsable(site) {
            return site
        }
        return nil
    }

    /// Place label for geocode search when coordinates are missing (catalog site place fields first).
    static func locationLabelForLookup(
        on activity: DiveActivity,
        catalogSites: [DiveSite] = []
    ) -> String? {
        if let matched = DiveActivitySiteAssociation.previewBestMatch(for: activity, catalogSites: catalogSites) {
            let region = matched.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = matched.country.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let name = matched.siteName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        let importedLocation = activity.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !importedLocation.isEmpty { return importedLocation }
        let importedSite = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return importedSite.isEmpty ? nil : importedSite
    }

    @MainActor
    static func resolveMissingOffsets(for activities: [DiveActivity]) async {
        await resolveMissingOffsets(for: activities, catalogSites: [], resolver: MapKitGeocodingTimeZoneResolver.shared)
    }

    @MainActor
    static func resolveMissingOffsets(
        for activities: [DiveActivity],
        catalogSites: [DiveSite] = [],
        resolver: (any GeocodingTimeZoneResolving)? = nil
    ) async {
        let resolvedResolver = resolver ?? MapKitGeocodingTimeZoneResolver.shared
        for activity in activities where activity.timeZoneOffsetSeconds == nil {
            await resolveMissingOffset(for: activity, catalogSites: catalogSites, resolver: resolvedResolver)
            await Task.yield()
        }
    }

    @MainActor
    static func resolveMissingOffset(for activity: DiveActivity) async {
        await resolveMissingOffset(for: activity, catalogSites: [], resolver: MapKitGeocodingTimeZoneResolver.shared)
    }

    @MainActor
    static func resolveMissingOffset(
        for activity: DiveActivity,
        catalogSites: [DiveSite] = [],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard activity.timeZoneOffsetSeconds == nil else { return }

        if let matched = DiveActivitySiteAssociation.previewBestMatch(
            for: activity,
            catalogSites: catalogSites
        ),
           let offset = DiveSiteTimeZoneResolution.offsetSeconds(for: matched, at: activity.startTime) {
            activity.timeZoneOffsetSeconds = offset
            return
        }

        guard let coordinate = coordinateForLookup(on: activity, catalogSites: catalogSites)
        else { return }

        let input = DiveGeographicTimeZoneLookup.CoordinateInput(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        if let timeZone = await resolver.timeZone(for: input) {
            activity.timeZoneOffsetSeconds = timeZone.secondsFromGMT(for: activity.startTime)
            if let site = activity.diveSite ?? DiveActivitySiteAssociation.previewBestMatch(
                for: activity,
                catalogSites: catalogSites
            ) {
                DiveSiteTimeZoneResolution.persist(timeZone, on: site, at: activity.startTime)
            }
        }
    }
}
