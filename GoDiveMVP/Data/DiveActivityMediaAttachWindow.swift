import Foundation

/// Inclusive capture-time range for matching Apple Photos assets to a dive.
///
/// Windows are built from the dive's **local wall-clock start** (logbook dive time) in the resolved dive
/// timezone, then converted to absolute **`Date`** bounds for PhotoKit. **`contains(_:for:)`** compares
/// capture instants on that same local timeline.
struct DiveActivityMediaAttachWindow: Equatable, Sendable {
    var inclusiveStart: Date
    var inclusiveEnd: Date

    nonisolated var durationSeconds: TimeInterval {
        max(inclusiveEnd.timeIntervalSince(inclusiveStart), 0)
    }

    nonisolated func contains(_ captureDate: Date) -> Bool {
        captureDate >= inclusiveStart && captureDate <= inclusiveEnd
    }

    /// Auto-attach match test using the Photos library **`creationDate`**.
    ///
    /// Many action cameras (e.g. **GoPro**) write **local** wall-clock time into the QuickTime field the
    /// system reads as **UTC** (no embedded timezone), so once imported, **`PHAsset.creationDate`** lands one
    /// UTC offset away from a watch dive's true-UTC window (the dive computer records real UTC). The same
    /// offset-sized gap shows up if the dive's own UTC parsing is slightly off. We therefore also accept the
    /// asset when removing the **dive-local UTC offset** lands its instant inside the window. This only ever
    /// *adds* matches — a correctly-zoned asset still passes the direct test, so nothing is lost.
    ///
    /// EXIF capture time stays out of the decision: cameras without **`OffsetTimeOriginal`** yield mis-zoned
    /// values, so it must never reject a match (it is only used later for display ordering).
    nonisolated func shouldAttachAsset(
        creationDate: Date?,
        diveLocalOffsetSeconds: Int? = nil
    ) -> Bool {
        guard let creationDate else { return false }
        if contains(creationDate) { return true }
        if let offset = diveLocalOffsetSeconds, offset != 0 {
            let recovered = creationDate.addingTimeInterval(TimeInterval(-offset))
            if contains(recovered) { return true }
        }
        return false
    }

    /// Whether **`captureDate`** falls within this window on the dive's local timeline.
    nonisolated func contains(_ captureDate: Date, for activity: DiveActivity) -> Bool {
        let timeZone = Self.resolvedTimeZone(for: activity, at: captureDate)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let captureLocal = Self.localWallClockInstant(captureDate, calendar: calendar)
        return captureLocal >= inclusiveStart && captureLocal <= inclusiveEnd
    }

    /// Dive window from local logbook start through computed end (bottom time, session duration, or fallback).
    nonisolated static func window(
        for activity: DiveActivity,
        paddingSeconds: TimeInterval = defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow {
        let timeZone = resolvedTimeZone(for: activity)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let anchor = localStartAnchor(for: activity.startTime, calendar: calendar)
        let durationSeconds = Int(diveDurationSeconds(for: activity).rounded(.towardZero))
        let padding = Int(paddingSeconds.rounded(.towardZero))

        let inclusiveStart = calendar.date(byAdding: .second, value: -padding, to: anchor)
            ?? anchor.addingTimeInterval(-paddingSeconds)
        let diveEnd = calendar.date(byAdding: .second, value: durationSeconds, to: anchor)
            ?? anchor.addingTimeInterval(TimeInterval(durationSeconds))
        let inclusiveEnd = calendar.date(byAdding: .second, value: padding, to: diveEnd)
            ?? diveEnd.addingTimeInterval(paddingSeconds)

        return DiveActivityMediaAttachWindow(
            inclusiveStart: inclusiveStart,
            inclusiveEnd: inclusiveEnd
        )
    }

    /// Wider absolute bounds for PhotoKit **`creationDate`** queries: full dive-local calendar day(s) spanned by the precise window.
    nonisolated static func photoLibraryFetchWindow(
        for activity: DiveActivity,
        paddingSeconds: TimeInterval = defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow {
        let precise = window(for: activity, paddingSeconds: paddingSeconds)
        let timeZone = resolvedTimeZone(for: activity)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let localStartDay = calendar.startOfDay(for: precise.inclusiveStart)
        let localEndDay = calendar.startOfDay(for: precise.inclusiveEnd)
        // Pad a day on each side so offset-recovery assets (camera local-as-UTC, up to a full UTC offset
        // away) near a local midnight are still fetched before the precise + offset test runs.
        let fetchStart = calendar.date(byAdding: .day, value: -1, to: localStartDay)
            ?? localStartDay.addingTimeInterval(-86_400)
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: localEndDay)
            ?? precise.inclusiveEnd.addingTimeInterval(86_400)

        return DiveActivityMediaAttachWindow(
            inclusiveStart: min(fetchStart, precise.inclusiveStart),
            inclusiveEnd: max(fetchEnd, precise.inclusiveEnd)
        )
    }

    /// Smallest span that covers every dive window (for a single Photos fetch during backfill).
    nonisolated static func unionFetchWindow(
        for activities: [DiveActivity],
        paddingSeconds: TimeInterval = defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow? {
        guard !activities.isEmpty else { return nil }
        let windows = activities.map { photoLibraryFetchWindow(for: $0, paddingSeconds: paddingSeconds) }
        guard let minStart = windows.map(\.inclusiveStart).min(),
              let maxEnd = windows.map(\.inclusiveEnd).max()
        else { return nil }
        return DiveActivityMediaAttachWindow(inclusiveStart: minStart, inclusiveEnd: maxEnd)
    }

    /// Same padding as **`DiveActivityDuplicateMatcher`** start tolerance (surface-interval photos).
    nonisolated static let defaultPaddingSeconds: TimeInterval = 120

    nonisolated static func diveDurationSeconds(for activity: DiveActivity) -> TimeInterval {
        if let bottom = activity.bottomTimeSeconds, bottom > 0 {
            return TimeInterval(bottom)
        }
        if activity.durationMinutes > 0 {
            return TimeInterval(activity.durationMinutes) * 60
        }
        return defaultUnknownDiveDurationSeconds
    }

    /// Manual / incomplete rows may have zero duration until edited.
    nonisolated static let defaultUnknownDiveDurationSeconds: TimeInterval = 90 * 60

    /// When multiple dives match, prefer the narrowest window, then closest local **`startTime`**.
    nonisolated static func bestMatchingActivity(
        for captureDate: Date,
        among activities: [DiveActivity]
    ) -> DiveActivity? {
        let matches = activities.filter { window(for: $0).contains(captureDate, for: $0) }
        guard !matches.isEmpty else { return nil }
        if matches.count == 1 { return matches[0] }
        return matches.min { lhs, rhs in
            let leftSpan = window(for: lhs).durationSeconds
            let rightSpan = window(for: rhs).durationSeconds
            if leftSpan != rightSpan { return leftSpan < rightSpan }
            let leftDelta = abs(lhs.startTime.timeIntervalSince(captureDate))
            let rightDelta = abs(rhs.startTime.timeIntervalSince(captureDate))
            return leftDelta < rightDelta
        }
    }

    /// Dive-local timezone for media matching (site IANA id, persisted site offset, activity offset, then geography).
    nonisolated static func resolvedTimeZone(for activity: DiveActivity, at referenceInstant: Date? = nil) -> TimeZone {
        let instant = referenceInstant ?? activity.startTime

        if let site = activity.diveSite,
           let identifier = normalizedTimeZoneIdentifier(site.timeZoneIdentifier),
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        if let site = activity.diveSite,
           let offset = DiveSiteTimeZoneResolution.offsetSeconds(for: site, at: instant),
           let timeZone = TimeZone(secondsFromGMT: offset) {
            return timeZone
        }

        if let offset = activity.timeZoneOffsetSeconds,
           let timeZone = TimeZone(secondsFromGMT: offset) {
            return timeZone
        }

        if let entry = activity.entryCoordinate,
           DiveMapCoordinateResolver.isUsable(entry),
           let hours = DiveSiteGeographyTimeZoneInference.uddfHoursFromUTC(
               latitude: entry.latitude,
               longitude: entry.longitude,
               at: instant
           ) {
            let offset = DiveDateTimeParsing.uddfTimeZoneHoursToOffsetSeconds(hours)
            if let timeZone = TimeZone(secondsFromGMT: offset) {
                return timeZone
            }
        }

        if let hours = DiveSiteGeographyTimeZoneInference.uddfHoursFromLocationName(
            locationLabel(for: activity),
            at: instant
        ) {
            let offset = DiveDateTimeParsing.uddfTimeZoneHoursToOffsetSeconds(hours)
            if let timeZone = TimeZone(secondsFromGMT: offset) {
                return timeZone
            }
        }

        return TimeZone(secondsFromGMT: 0) ?? .gmt
    }

    /// Logbook local start: wall-clock components of **`startTime`** in the dive timezone.
    nonisolated static func localStartAnchor(for startTime: Date, calendar: Calendar) -> Date {
        localWallClockInstant(startTime, calendar: calendar)
    }

    nonisolated static func localWallClockInstant(_ instant: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: instant
        )
        return calendar.date(from: components) ?? instant
    }

    private nonisolated static func locationLabel(for activity: DiveActivity) -> String? {
        let location = activity.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !location.isEmpty { return location }
        let site = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return site.isEmpty ? nil : site
    }

    private nonisolated static func normalizedTimeZoneIdentifier(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
