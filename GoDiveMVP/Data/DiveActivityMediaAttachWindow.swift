import Foundation

/// Inclusive capture-time range for matching Apple Photos assets to a dive.
struct DiveActivityMediaAttachWindow: Equatable, Sendable {
    var inclusiveStart: Date
    var inclusiveEnd: Date

    nonisolated var durationSeconds: TimeInterval {
        max(inclusiveEnd.timeIntervalSince(inclusiveStart), 0)
    }

    nonisolated func contains(_ captureDate: Date) -> Bool {
        captureDate >= inclusiveStart && captureDate <= inclusiveEnd
    }

    /// Dive window from **`startTime`** through computed end (bottom time, session duration, or fallback).
    nonisolated static func window(
        for activity: DiveActivity,
        paddingSeconds: TimeInterval = defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow {
        let start = activity.startTime
        let duration = diveDurationSeconds(for: activity)
        let end = start.addingTimeInterval(duration)
        return DiveActivityMediaAttachWindow(
            inclusiveStart: start.addingTimeInterval(-paddingSeconds),
            inclusiveEnd: end.addingTimeInterval(paddingSeconds)
        )
    }

    /// Smallest span that covers every dive window (for a single Photos fetch during backfill).
    nonisolated static func unionFetchWindow(
        for activities: [DiveActivity],
        paddingSeconds: TimeInterval = defaultPaddingSeconds
    ) -> DiveActivityMediaAttachWindow? {
        guard !activities.isEmpty else { return nil }
        let windows = activities.map { window(for: $0, paddingSeconds: paddingSeconds) }
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

    /// When multiple dives match, prefer the narrowest window, then closest **`startTime`**.
    nonisolated static func bestMatchingActivity(
        for captureDate: Date,
        among activities: [DiveActivity]
    ) -> DiveActivity? {
        let matches = activities.filter { window(for: $0).contains(captureDate) }
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
}
