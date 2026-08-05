import Foundation

/// Draft values for the Trip Planner form before persisting a **`DiveTrip`**.
struct DiveTripFormValues: Equatable, Sendable {
    var title: String = ""
    var startDate: Date = .now
    var endDate: Date = .now
    /// Becomes **true** after the user picks a start day (required to save a new trip).
    var hasChosenStartDate: Bool = false
    /// Ordered destination countries (same vocabulary as **`DiveSite.country`** / flag picker).
    var selectedCountries: [String] = []

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Comma-separated bridge for tests and legacy call sites.
    var countriesText: String {
        get { Self.countriesText(from: selectedCountries) }
        set { selectedCountries = Self.normalizedCountries(from: newValue) }
    }

    var parsedCountries: [String] {
        Self.normalizeCountryList(selectedCountries)
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
        hasChosenStartDate
            && hasValidDateRange
            && !trimmedTitle.isEmpty
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

    /// Parsed labels with catalog canonical names (e.g. Dutch Caribbean → Caribbean Netherlands).
    nonisolated static func normalizedCountries(from text: String) -> [String] {
        normalizeCountryList(parseCountries(from: text))
    }

    nonisolated static func normalizeCountryList(_ countries: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in countries {
            let canonical = DiveSiteCountryPresentation.canonicalDisplayName(for: raw)
            guard !canonical.isEmpty else { continue }
            let key = canonical.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(canonical)
        }
        return result
    }

    nonisolated static func countriesText(from countries: [String]) -> String {
        normalizeCountryList(countries).joined(separator: ", ")
    }

    nonisolated static func toggleCountry(_ raw: String, in countries: inout [String]) {
        let canonical = DiveSiteCountryPresentation.canonicalDisplayName(for: raw)
        guard !canonical.isEmpty else { return }
        if let index = countries.firstIndex(where: {
            $0.caseInsensitiveCompare(canonical) == .orderedSame
        }) {
            countries.remove(at: index)
        } else {
            countries.append(canonical)
        }
    }

    init() {}

    func makeDiveTrip(plannedSiteIDs: [UUID] = []) -> DiveTrip {
        let normalized = DiveTripDateRange.normalizedRange(start: startDate, end: endDate)
        return DiveTrip(
            startDate: normalized.start,
            endDate: normalized.end,
            countries: parsedCountries,
            title: trimmedTitle,
            plannedSiteIDs: plannedSiteIDs
        )
    }

    init(from trip: DiveTrip) {
        title = trip.title ?? ""
        startDate = trip.startDate
        endDate = trip.endDate
        hasChosenStartDate = true
        selectedCountries = Self.normalizeCountryList(trip.countries)
    }

    mutating func apply(to trip: DiveTrip) {
        let normalized = DiveTripDateRange.normalizedRange(start: startDate, end: endDate)
        trip.startDate = normalized.start
        trip.endDate = normalized.end
        trip.title = trimmedTitle
        trip.countries = parsedCountries
        trip.updatedAt = .now
    }

    /// Updates start, marks start as chosen, and moves end into that year/month (same day when end was unset).
    mutating func setStartDate(_ date: Date, calendar: Calendar = .current) {
        let wasChosen = hasChosenStartDate
        startDate = calendar.startOfDay(for: date)
        hasChosenStartDate = true
        if !wasChosen {
            endDate = startDate
        } else {
            endDate = DiveTripDateRangePickerPresentation.endDateDefaultedToStartMonth(
                start: startDate,
                currentEnd: endDate,
                calendar: calendar
            )
        }
    }

    mutating func setEndDate(_ date: Date, calendar: Calendar = .current) {
        let endDay = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)
        endDate = endDay < startDay ? startDay : endDay
    }
}
