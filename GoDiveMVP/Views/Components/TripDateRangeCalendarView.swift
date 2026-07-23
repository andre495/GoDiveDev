import SwiftUI
import UIKit

/// One inline calendar for selecting an inclusive trip start–end range.
struct TripDateRangeCalendarView: UIViewRepresentable {
    /// Single binding so start/end update atomically (avoids a one-frame invalid range in the form footer).
    @Binding var dateRange: (start: Date, end: Date)

    var calendar: Calendar = .current

    func makeCoordinator() -> Coordinator {
        Coordinator(dateRange: $dateRange, calendar: calendar)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = calendar
        view.locale = calendar.locale ?? .current
        view.tintColor = UIColor(AppTheme.Colors.tabSelected)
        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        view.selectionBehavior = selection
        context.coordinator.applyBindings(to: selection, in: view)
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        guard let selection = uiView.selectionBehavior as? UICalendarSelectionMultiDate else { return }
        context.coordinator.applyBindings(to: selection, in: uiView)
    }

    final class Coordinator: NSObject, UICalendarSelectionMultiDateDelegate {
        private let dateRange: Binding<(start: Date, end: Date)>
        private let calendar: Calendar

        private var lastSyncedStart: DateComponents?
        private var lastSyncedEnd: DateComponents?
        private var rangeAnchor: DateComponents?

        init(dateRange: Binding<(start: Date, end: Date)>, calendar: Calendar) {
            self.dateRange = dateRange
            self.calendar = calendar
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didSelectDate dateComponents: DateComponents
        ) {
            applyUserTap(dateComponents, to: selection)
        }

        func multiDateSelection(
            _ selection: UICalendarSelectionMultiDate,
            didDeselectDate dateComponents: DateComponents
        ) {
            applyUserTap(dateComponents, to: selection)
        }

        func applyBindings(to selection: UICalendarSelectionMultiDate, in calendarView: UICalendarView) {
            let range = dateRange.wrappedValue
            let startComponents = DiveTripDateRangePickerPresentation.dayComponents(
                for: range.start,
                calendar: calendar
            )
            let endComponents = DiveTripDateRangePickerPresentation.dayComponents(
                for: range.end,
                calendar: calendar
            )

            if DiveTripDateRangePickerPresentation.sameDayComponents(startComponents, lastSyncedStart),
               DiveTripDateRangePickerPresentation.sameDayComponents(endComponents, lastSyncedEnd)
            {
                return
            }

            let highlighted = DiveTripDateRangePickerPresentation.dayComponentsInRange(
                start: range.start,
                end: range.end,
                calendar: calendar
            )
            selection.setSelectedDates(highlighted, animated: false)
            rangeAnchor = startComponents
            lastSyncedStart = startComponents
            lastSyncedEnd = endComponents

            calendarView.visibleDateComponents = startComponents
        }

        private func applyUserTap(_ tapped: DateComponents, to selection: UICalendarSelectionMultiDate) {
            let startComponents: DateComponents
            let endComponents: DateComponents

            if let anchor = rangeAnchor,
               !DiveTripDateRangePickerPresentation.sameDayComponents(anchor, tapped)
            {
                startComponents = anchor
                endComponents = tapped
                rangeAnchor = nil
            } else {
                startComponents = tapped
                endComponents = tapped
                rangeAnchor = tapped
            }

            guard let normalized = DiveTripDateRangePickerPresentation.normalizedDates(
                startComponents: startComponents,
                endComponents: endComponents,
                calendar: calendar
            ) else { return }

            let syncedStart = DiveTripDateRangePickerPresentation.dayComponents(
                for: normalized.start,
                calendar: calendar
            )
            let syncedEnd = DiveTripDateRangePickerPresentation.dayComponents(
                for: normalized.end,
                calendar: calendar
            )

            let highlighted = DiveTripDateRangePickerPresentation.dayComponentsInRange(
                start: normalized.start,
                end: normalized.end,
                calendar: calendar
            )
            selection.setSelectedDates(highlighted, animated: true)

            rangeAnchor = syncedStart
            lastSyncedStart = syncedStart
            lastSyncedEnd = syncedEnd
            dateRange.wrappedValue = (normalized.start, normalized.end)
        }
    }
}
