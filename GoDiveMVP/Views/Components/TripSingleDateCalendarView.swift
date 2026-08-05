import SwiftUI
import UIKit

/// Single-day **`UICalendarView`** — reports every tap (including the already-selected day).
struct TripSingleDateCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    /// Month shown in the calendar (defaults to the selected day).
    var visibleMonthAnchor: Date? = nil
    var onDateSelected: (Date) -> Void = { _ in }

    var calendar: Calendar = .current

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedDate: $selectedDate,
            onDateSelected: onDateSelected,
            calendar: calendar
        )
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = calendar
        view.locale = calendar.locale ?? .current
        view.tintColor = UIColor(AppTheme.Colors.tabSelected)
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        context.coordinator.applyBindings(
            to: selection,
            in: view,
            visibleMonthAnchor: visibleMonthAnchor
        )
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.onDateSelected = onDateSelected
        guard let selection = uiView.selectionBehavior as? UICalendarSelectionSingleDate else { return }
        context.coordinator.applyBindings(
            to: selection,
            in: uiView,
            visibleMonthAnchor: visibleMonthAnchor
        )
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        private let selectedDate: Binding<Date>
        var onDateSelected: (Date) -> Void
        private let calendar: Calendar

        private var lastSyncedDay: DateComponents?
        private var lastVisibleMonth: DateComponents?

        init(
            selectedDate: Binding<Date>,
            onDateSelected: @escaping (Date) -> Void,
            calendar: Calendar
        ) {
            self.selectedDate = selectedDate
            self.onDateSelected = onDateSelected
            self.calendar = calendar
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            guard let dateComponents,
                  let instant = calendar.date(from: dateComponents)
            else { return }
            let day = calendar.startOfDay(for: instant)
            let components = DiveTripDateRangePickerPresentation.dayComponents(for: day, calendar: calendar)
            lastSyncedDay = components
            selectedDate.wrappedValue = day
            onDateSelected(day)
        }

        func applyBindings(
            to selection: UICalendarSelectionSingleDate,
            in calendarView: UICalendarView,
            visibleMonthAnchor: Date?
        ) {
            let day = calendar.startOfDay(for: selectedDate.wrappedValue)
            let dayComponents = DiveTripDateRangePickerPresentation.dayComponents(
                for: day,
                calendar: calendar
            )
            if !DiveTripDateRangePickerPresentation.sameDayComponents(dayComponents, lastSyncedDay) {
                selection.setSelected(dayComponents, animated: false)
                lastSyncedDay = dayComponents
            }

            let visibleSource = visibleMonthAnchor.map { calendar.startOfDay(for: $0) } ?? day
            let visibleComponents = DiveTripDateRangePickerPresentation.dayComponents(
                for: visibleSource,
                calendar: calendar
            )
            let visibleMonth = DateComponents(
                year: visibleComponents.year,
                month: visibleComponents.month
            )
            if !Self.sameYearMonth(visibleMonth, lastVisibleMonth) {
                calendarView.visibleDateComponents = visibleComponents
                lastVisibleMonth = visibleMonth
            }
        }

        private nonisolated static func sameYearMonth(_ lhs: DateComponents?, _ rhs: DateComponents?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (left?, right?):
                return left.year == right.year && left.month == right.month
            default:
                return false
            }
        }
    }
}
