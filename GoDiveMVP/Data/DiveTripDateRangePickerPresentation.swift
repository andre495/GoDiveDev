import CoreGraphics
import Foundation

/// Maps calendar-day selection to trip form **`startDate`** / **`endDate`** values.
enum DiveTripDateRangePickerPresentation: Sendable {

    nonisolated static let calendarHeight: CGFloat = 340

    nonisolated static func dayComponents(for date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
    }

    nonisolated static func sameDayComponents(_ lhs: DateComponents?, _ rhs: DateComponents?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return left.year == right.year && left.month == right.month && left.day == right.day
        default:
            return false
        }
    }

    /// All calendar-day components from `start` through `end` (inclusive).
    nonisolated static func dayComponentsInRange(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> [DateComponents] {
        let normalized = DiveTripDateRange.normalizedRange(
            start: start,
            end: end,
            calendar: calendar
        )
        guard let lastDay = calendar.date(from: dayComponents(for: normalized.end, calendar: calendar)),
              var cursor = calendar.date(from: dayComponents(for: normalized.start, calendar: calendar))
        else {
            return []
        }

        var components: [DateComponents] = []
        while cursor <= lastDay {
            components.append(dayComponents(for: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return components
    }

    /// Resolves UIKit range selection into normalized start-of-day instants (single-day when end is unset).
    nonisolated static func normalizedDates(
        startComponents: DateComponents?,
        endComponents: DateComponents?,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        guard let startComponents,
              let startInstant = calendar.date(from: startComponents)
        else { return nil }

        let startDay = calendar.startOfDay(for: startInstant)
        guard let endComponents,
              let endInstant = calendar.date(from: endComponents)
        else {
            return (startDay, startDay)
        }

        return DiveTripDateRange.normalizedRange(
            start: startDay,
            end: calendar.startOfDay(for: endInstant),
            calendar: calendar
        )
    }
}
