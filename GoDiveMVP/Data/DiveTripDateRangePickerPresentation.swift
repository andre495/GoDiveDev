import CoreGraphics
import Foundation

/// Start / end date helpers for the Trip Planner form pickers.
enum DiveTripDateRangePickerPresentation: Sendable {
    nonisolated static let startDatePickerTitle = "Start"
    nonisolated static let endDatePickerTitle = "End"
    nonisolated static let startDateFieldPlaceholder = "Select start date"
    nonisolated static let endDateFieldPlaceholder = "Select end date"
    nonisolated static let startDateFieldAccessibilityIdentifier = "TripPlanner.StartDateField"
    nonisolated static let endDateFieldAccessibilityIdentifier = "TripPlanner.EndDateField"
    nonisolated static let startDateAccessibilityIdentifier = "TripPlanner.StartDate"
    nonisolated static let endDateAccessibilityIdentifier = "TripPlanner.EndDate"
    /// Layout height for each progressive single-day calendar.
    nonisolated static let singleCalendarHeight: CGFloat = 280
    /// Slight shrink so **`UICalendarView`** does not clip against Form row edges.
    nonisolated static let singleCalendarScale: CGFloat = 0.88
    nonisolated static let singleCalendarHorizontalInset: CGFloat = 28

    nonisolated static func formattedFieldDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// End calendar is shown only after the user has picked a start day.
    nonisolated static func shouldShowEndDateControls(hasChosenStartDate: Bool) -> Bool {
        hasChosenStartDate
    }

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

    /// After start is chosen, place end in the same year/month (keep day when possible; never before start).
    /// Keeps the end date picker showing the start picker’s month.
    nonisolated static func endDateDefaultedToStartMonth(
        start: Date,
        currentEnd: Date,
        calendar: Calendar = .current
    ) -> Date {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: currentEnd)
        let startYear = calendar.component(.year, from: startDay)
        let startMonth = calendar.component(.month, from: startDay)
        let endDayOfMonth = calendar.component(.day, from: endDay)

        var monthStartComponents = DateComponents(year: startYear, month: startMonth, day: 1)
        guard let monthStart = calendar.date(from: monthStartComponents),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return startDay
        }

        monthStartComponents.day = min(endDayOfMonth, dayRange.count)
        let aligned = calendar.date(from: monthStartComponents).map { calendar.startOfDay(for: $0) } ?? startDay
        return aligned < startDay ? startDay : aligned
    }
}
