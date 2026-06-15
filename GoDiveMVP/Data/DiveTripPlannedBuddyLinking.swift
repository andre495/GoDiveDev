import Foundation
import SwiftData

/// Adds / removes roster buddies on a planned **`DiveTrip`**.
enum DiveTripPlannedBuddyLinking {

    static func plannedBuddies(for trip: DiveTrip) -> [DiveBuddy] {
        trip.buddyLinks
            .compactMap(\.buddy)
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    static func isBuddyOnTrip(buddyID: UUID, trip: DiveTrip) -> Bool {
        trip.buddyLinks.contains { $0.buddyID == buddyID }
    }

    @discardableResult
    static func addBuddy(
        _ buddy: DiveBuddy,
        to trip: DiveTrip,
        modelContext: ModelContext
    ) -> DiveTripBuddyLink? {
        guard !isBuddyOnTrip(buddyID: buddy.id, trip: trip) else { return nil }
        let link = DiveTripBuddyLink(trip: trip, buddy: buddy)
        modelContext.insert(link)
        trip.updatedAt = .now
        return link
    }

    static func removeBuddy(
        _ buddy: DiveBuddy,
        from trip: DiveTrip,
        modelContext: ModelContext
    ) {
        let matches = trip.buddyLinks.filter { $0.buddyID == buddy.id }
        for link in matches {
            modelContext.delete(link)
        }
        if !matches.isEmpty {
            trip.buddyLinks.removeAll { $0.buddyID == buddy.id }
            trip.updatedAt = .now
        }
    }

    static func toggleBuddy(
        _ buddy: DiveBuddy,
        on trip: DiveTrip,
        modelContext: ModelContext
    ) {
        if isBuddyOnTrip(buddyID: buddy.id, trip: trip) {
            removeBuddy(buddy, from: trip, modelContext: modelContext)
        } else {
            addBuddy(buddy, to: trip, modelContext: modelContext)
        }
    }
}
