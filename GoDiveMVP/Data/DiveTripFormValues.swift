import Foundation

/// Draft values for the Trip Planner form before persisting a **`DiveTrip`**.
struct DiveTripFormValues: Equatable, Sendable {
    var title: String = ""
    var startDate: Date = .now
    var endDate: Date = .now
    /// Comma-separated destination countries (same vocabulary as **`DiveSite.country`**).
    var countriesText: String = ""

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedCountries: [String] {
        Self.parseCountries(from: countriesText)
    }

    var hasValidDateRange: Bool {
        DiveTripDateRange.isValidOrderedRange(start: startDate, end: endDate)
    }

    func overlappingTrip(
        among ownerTrips: [DiveTrip],
        excludingTripID: UUID? = nil,
        calendar: Calendar = .current
    ) -> DiveTrip? {
        DiveTripOverlapValidation.firstOverlappingTrip(
            start: startDate,
            end: endDate,
            among: ownerTrips,
            excludingTripID: excludingTripID,
            calendar: calendar
        )
    }

    func canSave(
        existingOwnerTrips: [DiveTrip] = [],
        excludingTripID: UUID? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        hasValidDateRange
            && (!parsedCountries.isEmpty || !trimmedTitle.isEmpty)
            && overlappingTrip(
                among: existingOwnerTrips,
                excludingTripID: excludingTripID,
                calendar: calendar
            ) == nil
    }

    /// Backward-compatible save gate when overlap context is unavailable (tests only).
    var canSave: Bool {
        canSave(existingOwnerTrips: [])
    }

    nonisolated static func parseCountries(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    init() {}

    func makeDiveTrip(plannedSites: [DiveSite]) -> DiveTrip {
        let normalized = DiveTripDateRange.normalizedRange(start: startDate, end: endDate)
        return DiveTrip(
            startDate: normalized.start,
            endDate: normalized.end,
            countries: parsedCountries,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            plannedSites: plannedSites
        )
    }

    init(from trip: DiveTrip) {
        title = trip.title ?? ""
        startDate = trip.startDate
        endDate = trip.endDate
        countriesText = trip.countries.joined(separator: ", ")
    }

    mutating func apply(to trip: DiveTrip, plannedSites: [DiveSite]) {
        let normalized = DiveTripDateRange.normalizedRange(start: startDate, end: endDate)
        trip.startDate = normalized.start
        trip.endDate = normalized.end
        trip.countries = parsedCountries
        trip.title = trimmedTitle.isEmpty ? nil : trimmedTitle
        trip.plannedSites = plannedSites
        trip.updatedAt = .now
    }
}
