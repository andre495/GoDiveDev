import Foundation

/// Reinterprets MacDive naive **`datetime`** as dive-local wall time when import first stored the wrong UTC instant.
enum UddfNaiveDatetimeStartTimeCorrection: Sendable {

    /// **`activities`** from **`UddfDiveFileDecoder`** (uses transient **`uddfImportDatetimeRaw`** when set).
    @MainActor
    static func reconcile(
        _ activities: [DiveActivity],
        catalogSites: [DiveSite] = [],
        resolver: (any GeocodingTimeZoneResolving)? = nil
    ) async {
        let resolvedResolver = resolver ?? MapKitGeocodingTimeZoneResolver.shared
        for activity in activities where activity.source == .macDive {
            await reconcileOne(activity, catalogSites: catalogSites, resolver: resolvedResolver)
        }
    }

    @MainActor
    private static func reconcileOne(
        _ activity: DiveActivity,
        catalogSites: [DiveSite],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        if activity.uddfWatchNaiveDatetimeSemantics == .diveLocalWallTime {
            return
        }

        if activity.uddfWatchNaiveDatetimeSemantics == .utcWallClock {
            await ensureDisplayOffsetForUtcWallClock(
                activity,
                catalogSites: catalogSites,
                resolver: resolver
            )
            return
        }

        guard let raw = importDatetimeRaw(for: activity),
              let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
                  on: activity,
                  catalogSites: catalogSites
              )
        else { return }

        guard isUtcWallClockInstant(startTime: activity.startTime, rawDatetime: raw) else { return }

        let matchedCatalogSite = DiveActivitySiteAssociation.previewBestMatch(
            for: activity,
            catalogSites: catalogSites
        )
        guard let siteHours = await resolvedSiteTimeZoneHours(
            for: activity,
            rawDatetime: raw,
            coordinate: coordinate,
            catalogSite: matchedCatalogSite,
            resolver: resolver
        ) else { return }

        guard let parsed = DiveDateTimeParsing.parseUddfDateTime(
            raw,
            siteTimeZoneHours: siteHours,
            siteLatitude: coordinate.latitude,
            siteLongitude: coordinate.longitude,
            siteLocationName: DiveActivityTimeZoneResolution.locationLabelForLookup(
                on: activity,
                catalogSites: catalogSites
            )
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

    /// Garmin / MacDive FIT exports store naive **`datetime`** as **UTC wall clock**; **`startTime`** is already correct.
    @MainActor
    private static func ensureDisplayOffsetForUtcWallClock(
        _ activity: DiveActivity,
        catalogSites: [DiveSite],
        resolver: any GeocodingTimeZoneResolving
    ) async {
        guard activity.timeZoneOffsetSeconds == nil else { return }

        let matchedCatalogSite = DiveActivitySiteAssociation.previewBestMatch(
            for: activity,
            catalogSites: catalogSites
        )
        if let site = matchedCatalogSite,
           let offset = DiveSiteTimeZoneResolution.offsetSeconds(for: site, at: activity.startTime) {
            activity.timeZoneOffsetSeconds = offset
            return
        }

        guard let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
            on: activity,
            catalogSites: catalogSites
        ) else { return }

        let raw = activity.uddfImportDatetimeRaw?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let siteHours = await resolvedSiteTimeZoneHours(
            for: activity,
            rawDatetime: raw.isEmpty ? (utcWallTimeRaw(from: activity.startTime) ?? "") : raw,
            coordinate: coordinate,
            catalogSite: matchedCatalogSite,
            resolver: resolver
        ) else { return }

        activity.timeZoneOffsetSeconds = DiveDateTimeParsing.uddfTimeZoneHoursToOffsetSeconds(siteHours)
    }

    private static func importDatetimeRaw(for activity: DiveActivity) -> String? {
        let fromTransient = activity.uddfImportDatetimeRaw?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromTransient.isEmpty { return fromTransient }
        return utcWallTimeRaw(from: activity.startTime)
    }

    /// **`true`** when **`startTime`** equals parsing **`rawDatetime`** as UTC wall clock (legacy import bug).
    nonisolated static func isUtcWallClockInstant(startTime: Date, rawDatetime: String) -> Bool {
        guard let utcParsed = DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(rawDatetime) else {
            return false
        }
        return abs(utcParsed.timeIntervalSince(startTime)) < 1.0
    }

    @MainActor
    private static func resolvedSiteTimeZoneHours(
        for activity: DiveActivity,
        rawDatetime: String,
        coordinate: DiveCoordinate,
        catalogSite: DiveSite?,
        resolver: any GeocodingTimeZoneResolving
    ) async -> Double? {
        if let offsetSeconds = activity.timeZoneOffsetSeconds {
            return Double(offsetSeconds) / 3600.0
        }

        let referenceInstant = DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(rawDatetime) ?? activity.startTime
        return await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationName: DiveActivityTimeZoneResolution.locationLabelForLookup(
                on: activity,
                catalogSites: catalogSite.map { [$0] } ?? []
            ),
            catalogSite: catalogSite,
            at: referenceInstant,
            resolver: resolver
        )
    }

    /// ISO-like wall time as previously interpreted in UTC (fallback when transient raw is cleared).
    nonisolated static func utcWallTimeRaw(from instant: Date) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: instant)
    }

    private static func shiftProfileTimestamps(on activity: DiveActivity, by delta: TimeInterval) {
        guard delta != 0 else { return }
        for point in activity.profilePoints {
            point.timestamp = point.timestamp.addingTimeInterval(delta)
        }
    }
}
