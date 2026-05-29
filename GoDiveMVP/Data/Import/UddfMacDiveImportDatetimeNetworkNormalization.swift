import Foundation

/// Re-parses MacDive naive **`datetime`** using network timezone lookup before persist (single + bulk UDDF).
enum UddfMacDiveImportDatetimeNetworkNormalization: Sendable {

    /// Applies to Suunto-style (dive-local) rows and unknown watch source; Garmin UTC rows use **`UddfNaiveDatetimeStartTimeCorrection`**.
    @MainActor
    static func apply(
        _ activities: [DiveActivity],
        catalogSites: [DiveSite] = [],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        for activity in activities where activity.source == .macDive {
            await applyOne(activity, catalogSites: catalogSites, resolver: resolver)
            await Task.yield()
        }
    }

    @MainActor
    private static func applyOne(
        _ activity: DiveActivity,
        catalogSites: [DiveSite],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard activity.uddfWatchNaiveDatetimeSemantics != .utcWallClock else { return }

        guard let raw = activity.uddfImportDatetimeRaw?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return }

        let matchedCatalogSite = DiveActivitySiteAssociation.previewBestMatch(
            for: activity,
            catalogSites: catalogSites
        )
        let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
            on: activity,
            catalogSites: catalogSites
        )
        let locationLabel = DiveActivityTimeZoneResolution.locationLabelForLookup(
            on: activity,
            catalogSites: catalogSites
        )
        let referenceInstant = DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw) ?? activity.startTime

        guard let siteHours = await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            locationName: locationLabel,
            catalogSite: matchedCatalogSite,
            at: referenceInstant,
            resolver: resolver
        ) else { return }

        guard let parsed = DiveDateTimeParsing.parseUddfDateTime(
            raw,
            siteTimeZoneHours: siteHours,
            siteLatitude: coordinate?.latitude,
            siteLongitude: coordinate?.longitude,
            siteLocationName: locationLabel,
            macDiveNaiveSemantics: activity.uddfWatchNaiveDatetimeSemantics
        ) else { return }

        let delta = parsed.instant.timeIntervalSince(activity.startTime)
        guard delta != 0 else {
            activity.timeZoneOffsetSeconds = parsed.timeZoneOffsetSeconds
            return
        }

        activity.startTime = parsed.instant
        activity.timeZoneOffsetSeconds = parsed.timeZoneOffsetSeconds
        shiftProfileTimestamps(on: activity, by: delta)
    }

    private static func shiftProfileTimestamps(on activity: DiveActivity, by delta: TimeInterval) {
        guard delta != 0 else { return }
        for point in activity.profilePoints {
            point.timestamp = point.timestamp.addingTimeInterval(delta)
        }
    }
}
