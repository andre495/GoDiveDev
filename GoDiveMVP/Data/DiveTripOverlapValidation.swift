import Foundation

/// Ensures owner trips use non-overlapping inclusive calendar-day windows.
enum DiveTripOverlapValidation: Sendable {

    nonisolated static func firstOverlappingTrip(
        start: Date,
        end: Date,
        among trips: [DiveTrip],
        excludingTripID: UUID? = nil,
        calendar: Calendar = .current
    ) -> DiveTrip? {
        guard DiveTripDateRange.isValidOrderedRange(start: start, end: end, calendar: calendar) else {
            return nil
        }
        return trips.first { trip in
            if let excludingTripID, trip.id == excludingTripID { return false }
            return DiveTripDateRange.rangesOverlap(
                start: start,
                end: end,
                otherStart: trip.startDate,
                otherEnd: trip.endDate,
                calendar: calendar
            )
        }
    }
}
