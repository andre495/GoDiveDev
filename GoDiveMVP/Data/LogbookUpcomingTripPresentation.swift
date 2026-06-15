import Foundation

/// Shout-out tile for the next upcoming owner trip at the top of the logbook.
struct LogbookUpcomingTripBannerData: Equatable, Sendable, Identifiable {
    var id: UUID { tripID }
    let tripID: UUID
    let eyebrow: String
    let displayTitle: String
    let dateLine: String

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tripID == rhs.tripID
            && lhs.eyebrow == rhs.eyebrow
            && lhs.displayTitle == rhs.displayTitle
            && lhs.dateLine == rhs.dateLine
    }
}

enum LogbookUpcomingTripPresentation: Sendable {

    nonisolated static let eyebrow = "Trip on the horizon"

    nonisolated static func isUpcoming(
        trip: DiveTrip,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        !DiveTripActivityLinking.hasStarted(
            trip: trip,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    /// Upcoming banner sits above async-built logbook rows — defer until rows (or stored empty state) are ready.
    nonisolated static func shouldShowInLogbookList(
        isFilteringLogbook: Bool,
        showsStoredDiveEmptyState: Bool,
        hasDisplayItems: Bool
    ) -> Bool {
        guard !isFilteringLogbook else { return false }
        if showsStoredDiveEmptyState { return true }
        return hasDisplayItems
    }

    nonisolated static func nearestUpcomingBanner(
        from trips: [DiveTrip],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> LogbookUpcomingTripBannerData? {
        guard let trip = trips
            .filter({ isUpcoming(trip: $0, referenceDate: referenceDate, calendar: calendar) })
            .min(by: { lhs, rhs in
                let leftStart = DiveTripDateRange.normalizedRange(
                    start: lhs.startDate,
                    end: lhs.endDate,
                    calendar: calendar
                ).start
                let rightStart = DiveTripDateRange.normalizedRange(
                    start: rhs.startDate,
                    end: rhs.endDate,
                    calendar: calendar
                ).start
                if leftStart != rightStart { return leftStart < rightStart }
                return lhs.createdAt < rhs.createdAt
            })
        else { return nil }

        return bannerData(for: trip)
    }

    nonisolated static func bannerData(for trip: DiveTrip) -> LogbookUpcomingTripBannerData {
        LogbookUpcomingTripBannerData(
            tripID: trip.id,
            eyebrow: eyebrow,
            displayTitle: trip.displayTitle,
            dateLine: TripPlannerPresentation.listRowSubtitle(for: trip)
        )
    }
}
