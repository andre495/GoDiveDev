import Foundation

/// Calendar-day semantics for trip windows and dive membership.
enum DiveTripDateRange: Sendable {

    /// **`true`** when **`instant`** falls on an inclusive **[start, end]** calendar-day range.
    nonisolated static func contains(
        _ instant: Date,
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let day = calendar.startOfDay(for: instant)
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let lower = min(startDay, endDay)
        let upper = max(startDay, endDay)
        return day >= lower && day <= upper
    }

    /// **`true`** when **`start`** falls on or before **`end`** on the calendar (same-day trips allowed).
    nonisolated static func isValidOrderedRange(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return startDay <= endDay
    }

    nonisolated static func normalizedRange(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        if startDay <= endDay {
            return (startDay, endDay)
        }
        return (endDay, startDay)
    }

    /// Inclusive calendar-day ranges overlap when they share at least one day.
    nonisolated static func rangesOverlap(
        start: Date,
        end: Date,
        otherStart: Date,
        otherEnd: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let lhs = normalizedRange(start: start, end: end, calendar: calendar)
        let rhs = normalizedRange(start: otherStart, end: otherEnd, calendar: calendar)
        return lhs.start <= rhs.end && rhs.start <= lhs.end
    }
}
