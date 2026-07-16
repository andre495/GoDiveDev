import Foundation

/// Lifecycle bucket for the Trips list (**`TripPlannerView`**).
enum TripPlannerListPhase: String, Sendable, CaseIterable, Identifiable {
    case upcoming
    case active
    case past

    var id: String { rawValue }
}

struct TripPlannerListSection: Identifiable {
    let phase: TripPlannerListPhase
    let trips: [DiveTrip]

    var id: TripPlannerListPhase { phase }
}

/// One row on **`TripPlannerView`** — compact title + secondary detail (logbook-style).
struct TripPlannerListRowDisplayData: Equatable, Sendable {
    let title: String
    let dateRangeLine: String
    let countriesLine: String?
    let linkedDiveCountLabel: String?
    let previewMediaPhotoID: UUID?

    var secondaryDetailLine: String {
        TripPlannerPresentation.listRowSecondaryDetail(
            dateRange: dateRangeLine,
            countriesLine: countriesLine
        )
    }
}

/// Copy and chrome for the Explore → Trip Planner flow.
enum TripPlannerPresentation: Sendable {
    nonisolated static let pageTitle = "Trips"
    nonisolated static let exploreChromeAccessibilityLabel = "Plan a trip"
    nonisolated static let exploreChromeSystemImage = "airplane"
    nonisolated static let newTripSheetTitle = "Plan a trip"
    nonisolated static let editTripSheetTitle = "Edit trip"
    nonisolated static let addTripCancelAccessibilityIdentifier = "TripAddSheet.Cancel"
    nonisolated static let addTripDoneAccessibilityIdentifier = "TripAddSheet.Done"
    nonisolated static let editTripCancelAccessibilityIdentifier = "TripEditSheet.Cancel"
    nonisolated static let editTripDoneAccessibilityIdentifier = "TripEditSheet.Done"
    nonisolated static let addTripToolbarAccessibilityLabel = "Plan a new trip"
    nonisolated static let editTripToolbarAccessibilityLabel = "Edit trip"
    nonisolated static let deleteTripConfirmationTitle = "Delete trip?"
    nonisolated static let upcomingSectionTitle = "Upcoming"
    nonisolated static let activeSectionTitle = "Active"
    nonisolated static let pastSectionTitle = "Past"
    nonisolated static func deleteTripConfirmationMessage(displayTitle: String) -> String {
        "This removes \(displayTitle) and unlinks it from your logbook dives. This cannot be undone."
    }
    nonisolated static let emptyStateTitle = "No trips planned"
    nonisolated static let emptyStateMessage = "Tap + in the corner to plan your first trip."

    nonisolated static func sectionTitle(for phase: TripPlannerListPhase) -> String {
        switch phase {
        case .upcoming:
            return upcomingSectionTitle
        case .active:
            return activeSectionTitle
        case .past:
            return pastSectionTitle
        }
    }

    nonisolated static func lifecyclePhase(
        for trip: DiveTrip,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TripPlannerListPhase {
        if !DiveTripActivityLinking.hasStarted(
            trip: trip,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            return .upcoming
        }

        let range = DiveTripDateRange.normalizedRange(
            start: trip.startDate,
            end: trip.endDate,
            calendar: calendar
        )
        let referenceDay = calendar.startOfDay(for: referenceDate)
        if referenceDay <= range.end {
            return .active
        }
        return .past
    }

    nonisolated static func listSections(
        from trips: [DiveTrip],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [TripPlannerListSection] {
        var buckets = Dictionary(uniqueKeysWithValues: TripPlannerListPhase.allCases.map { ($0, [DiveTrip]()) })
        for trip in trips {
            let phase = lifecyclePhase(for: trip, referenceDate: referenceDate, calendar: calendar)
            buckets[phase, default: []].append(trip)
        }

        return TripPlannerListPhase.allCases.compactMap { phase in
            let sectionTrips = sortedForSection(
                buckets[phase] ?? [],
                phase: phase,
                calendar: calendar
            )
            guard !sectionTrips.isEmpty else { return nil }
            return TripPlannerListSection(phase: phase, trips: sectionTrips)
        }
    }

    nonisolated static func sortedForList(_ trips: [DiveTrip], calendar: Calendar = .current) -> [DiveTrip] {
        sortedForSection(trips, phase: .past, calendar: calendar)
    }

    nonisolated static func sortedForSection(
        _ trips: [DiveTrip],
        phase: TripPlannerListPhase,
        calendar: Calendar = .current
    ) -> [DiveTrip] {
        switch phase {
        case .upcoming:
            return trips.sorted { lhs, rhs in
                let lhsStart = DiveTripDateRange.normalizedRange(
                    start: lhs.startDate,
                    end: lhs.endDate,
                    calendar: calendar
                ).start
                let rhsStart = DiveTripDateRange.normalizedRange(
                    start: rhs.startDate,
                    end: rhs.endDate,
                    calendar: calendar
                ).start
                if lhsStart != rhsStart { return lhsStart < rhsStart }
                return lhs.createdAt < rhs.createdAt
            }
        case .active:
            return trips.sorted { lhs, rhs in
                let lhsEnd = DiveTripDateRange.normalizedRange(
                    start: lhs.startDate,
                    end: lhs.endDate,
                    calendar: calendar
                ).end
                let rhsEnd = DiveTripDateRange.normalizedRange(
                    start: rhs.startDate,
                    end: rhs.endDate,
                    calendar: calendar
                ).end
                if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }
                let lhsStart = DiveTripDateRange.normalizedRange(
                    start: lhs.startDate,
                    end: lhs.endDate,
                    calendar: calendar
                ).start
                let rhsStart = DiveTripDateRange.normalizedRange(
                    start: rhs.startDate,
                    end: rhs.endDate,
                    calendar: calendar
                ).start
                if lhsStart != rhsStart { return lhsStart > rhsStart }
                return lhs.createdAt > rhs.createdAt
            }
        case .past:
            return trips.sorted { lhs, rhs in
                let lhsStart = DiveTripDateRange.normalizedRange(
                    start: lhs.startDate,
                    end: lhs.endDate,
                    calendar: calendar
                ).start
                let rhsStart = DiveTripDateRange.normalizedRange(
                    start: rhs.startDate,
                    end: rhs.endDate,
                    calendar: calendar
                ).start
                if lhsStart != rhsStart { return lhsStart > rhsStart }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    nonisolated static func listRowSubtitle(for trip: DiveTrip) -> String {
        listRowSecondaryDetail(
            dateRange: DiveTripPresentation.formattedDateRange(start: trip.startDate, end: trip.endDate),
            countriesLine: formattedCountries(from: trip.countries)
        )
    }

    nonisolated static func listRowSecondaryDetail(
        dateRange: String,
        countriesLine: String?
    ) -> String {
        if let countriesLine, !countriesLine.isEmpty {
            return "\(dateRange) · \(countriesLine)"
        }
        return dateRange
    }

    nonisolated static func listRowDisplayData(
        for trip: DiveTrip,
        phase: TripPlannerListPhase,
        previewMediaPhotoID: UUID? = nil
    ) -> TripPlannerListRowDisplayData {
        let dateRange = DiveTripPresentation.formattedDateRange(start: trip.startDate, end: trip.endDate)
        return TripPlannerListRowDisplayData(
            title: trip.displayTitle,
            dateRangeLine: dateRange,
            countriesLine: formattedCountries(from: trip.countries),
            linkedDiveCountLabel: showsLinkedDiveCount(for: phase)
                ? linkedDiveCountLabel(count: trip.activityLinks.count)
                : nil,
            previewMediaPhotoID: showsLinkedDiveCount(for: phase) ? previewMediaPhotoID : nil
        )
    }

    @MainActor
    static func listRowPreviewMediaPhotoID(
        phase: TripPlannerListPhase,
        linkedActivities: [DiveActivity]
    ) -> UUID? {
        guard showsLinkedDiveCount(for: phase) else { return nil }
        return TripDetailMediaPresentation.linkedMediaItems(from: linkedActivities).first?.id
    }

    nonisolated static func listRowAccessibilityLabel(for row: TripPlannerListRowDisplayData) -> String {
        var parts = [row.title]
        if let linkedDiveCountLabel = row.linkedDiveCountLabel {
            parts.append(linkedDiveCountLabel)
        }
        parts.append(
            listRowSecondaryDetail(
                dateRange: row.dateRangeLine,
                countriesLine: row.countriesLine
            )
        )
        if row.previewMediaPhotoID != nil {
            parts.append("Trip media preview available")
        }
        return parts.joined(separator: ", ")
    }

    nonisolated static func showsLinkedDiveCount(for phase: TripPlannerListPhase) -> Bool {
        switch phase {
        case .upcoming:
            false
        case .active, .past:
            true
        }
    }

    nonisolated static func linkedDiveCountLabel(count: Int) -> String {
        count == 1 ? "1 dive" : "\(count) dives"
    }

    nonisolated static func formattedCountries(from countries: [String]) -> String? {
        let trimmed = countries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return nil }
        return trimmed.joined(separator: ", ")
    }
}
