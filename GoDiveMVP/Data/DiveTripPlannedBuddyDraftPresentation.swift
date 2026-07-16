import Foundation
import SwiftData

/// In-memory planned-trip buddy selection — apply to SwiftData once on **Done**.
enum DiveTripPlannedBuddyDraftPresentation {

    nonisolated static func plannedBuddyIDs(on trip: DiveTrip) -> Set<UUID> {
        Set(trip.buddyLinks.compactMap(\.buddyID))
    }

    static func apply(
        draftBuddyIDs: Set<UUID>,
        to trip: DiveTrip,
        rosterByID: [UUID: DiveBuddy],
        modelContext: ModelContext
    ) {
        let current = plannedBuddyIDs(on: trip)
        let toRemove = current.subtracting(draftBuddyIDs)
        let toAdd = draftBuddyIDs.subtracting(current)

        for buddyID in toRemove {
            guard let buddy = rosterByID[buddyID]
                ?? trip.buddyLinks.first(where: { $0.buddyID == buddyID })?.buddy
            else { continue }
            DiveTripPlannedBuddyLinking.removeBuddy(buddy, from: trip, modelContext: modelContext)
        }

        for buddyID in toAdd {
            guard let buddy = rosterByID[buddyID] else { continue }
            DiveTripPlannedBuddyLinking.addBuddy(buddy, to: trip, modelContext: modelContext)
        }
    }
}
