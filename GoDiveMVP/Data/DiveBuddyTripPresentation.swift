import Foundation

/// Row copy for trips a buddy appears on (**`ViewDiveBuddyDetails`**).
struct DiveBuddyTripRowDisplayData: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let phaseLabel: String
    let secondaryDetailLine: String
    let linkedDiveCountLabel: String?
}

/// Resolves owner trips where a roster buddy is on the plan or tagged on linked dives.
enum DiveBuddyTripPresentation {

    nonisolated static let sectionTitle = "Trips together"

    static func isBuddyAssociated(
        buddyID: UUID,
        trip: DiveTrip,
        sharedDiveIDs: Set<UUID>
    ) -> Bool {
        if DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: buddyID, trip: trip) {
            return true
        }
        guard !sharedDiveIDs.isEmpty else { return false }
        return trip.linkedActivities.contains { sharedDiveIDs.contains($0.id) }
    }

    static func associatedTrips(
        buddyID: UUID,
        ownerProfileID: UUID,
        trips: [DiveTrip],
        sharedDiveIDs: Set<UUID>
    ) -> [DiveTrip] {
        trips.filter { trip in
            trip.ownerProfileID == ownerProfileID
                && isBuddyAssociated(buddyID: buddyID, trip: trip, sharedDiveIDs: sharedDiveIDs)
        }
    }

    static func sortedAssociatedTrips(
        _ trips: [DiveTrip],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [DiveTrip] {
        TripPlannerListPhase.allCases.flatMap { phase in
            let matching = trips.filter {
                TripPlannerPresentation.lifecyclePhase(
                    for: $0,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) == phase
            }
            return TripPlannerPresentation.sortedForSection(
                matching,
                phase: phase,
                calendar: calendar
            )
        }
    }

    static func rowDisplayData(
        for trip: DiveTrip,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> DiveBuddyTripRowDisplayData {
        let phase = TripPlannerPresentation.lifecyclePhase(
            for: trip,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let plannerRow = TripPlannerPresentation.listRowDisplayData(for: trip, phase: phase)
        return DiveBuddyTripRowDisplayData(
            id: trip.id,
            title: plannerRow.title,
            phaseLabel: TripPlannerPresentation.sectionTitle(for: phase),
            secondaryDetailLine: plannerRow.secondaryDetailLine,
            linkedDiveCountLabel: plannerRow.linkedDiveCountLabel
        )
    }

    nonisolated static func listRowSecondaryDetail(
        phaseLabel: String,
        secondaryDetailLine: String
    ) -> String {
        "\(phaseLabel) · \(secondaryDetailLine)"
    }

    nonisolated static func listRowAccessibilityLabel(for row: DiveBuddyTripRowDisplayData) -> String {
        var parts = [row.title, listRowSecondaryDetail(phaseLabel: row.phaseLabel, secondaryDetailLine: row.secondaryDetailLine)]
        if let linkedDiveCountLabel = row.linkedDiveCountLabel {
            parts.append(linkedDiveCountLabel)
        }
        return parts.joined(separator: ", ")
    }
}
