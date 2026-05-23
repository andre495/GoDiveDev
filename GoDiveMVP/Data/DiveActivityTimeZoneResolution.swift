import Foundation

/// Fills **`DiveActivity.timeZoneOffsetSeconds`** from dive GPS / linked site coordinates when import did not supply an offset.
enum DiveActivityTimeZoneResolution {

    /// Best coordinate for timezone lookup: entry GPS, then linked catalog site.
    static func coordinateForLookup(on activity: DiveActivity) -> DiveCoordinate? {
        if let entry = activity.entryCoordinate, DiveMapCoordinateResolver.isUsable(entry) {
            return entry
        }
        if let site = activity.siteCoordinate, DiveMapCoordinateResolver.isUsable(site) {
            return site
        }
        return nil
    }

    @MainActor
    static func resolveMissingOffsets(for activities: [DiveActivity]) async {
        await resolveMissingOffsets(for: activities, resolver: MapKitGeocodingTimeZoneResolver.shared)
    }

    @MainActor
    static func resolveMissingOffsets(
        for activities: [DiveActivity],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        for activity in activities where activity.timeZoneOffsetSeconds == nil {
            await resolveMissingOffset(for: activity, resolver: resolver)
            await Task.yield()
        }
    }

    @MainActor
    static func resolveMissingOffset(for activity: DiveActivity) async {
        await resolveMissingOffset(for: activity, resolver: MapKitGeocodingTimeZoneResolver.shared)
    }

    @MainActor
    static func resolveMissingOffset(
        for activity: DiveActivity,
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard activity.timeZoneOffsetSeconds == nil,
              let coordinate = coordinateForLookup(on: activity)
        else { return }

        let input = DiveGeographicTimeZoneLookup.CoordinateInput(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        if let offset = await DiveGeographicTimeZoneLookup.offsetSeconds(
            for: input,
            at: activity.startTime,
            resolver: resolver
        ) {
            activity.timeZoneOffsetSeconds = offset
        }
    }
}
