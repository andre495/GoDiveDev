import Foundation
import SwiftData

/// In-memory planned-trip buddy selection — apply to SwiftData once on **Done**.
enum DiveTripPlannedBuddyDraftPresentation {

    nonisolated static func plannedBuddyIDs(on trip: DiveTrip) -> Set<UUID> {
        Set(trip.buddyLinks.compactMap(\.buddyID))
    }

    /// Owner roster map plus SwiftData fallback for freshly inserted buddies not yet in `@Query`.
    static func rosterByID(
        ownedBuddies: [DiveBuddy],
        selectedBuddyIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [UUID: DiveBuddy] {
        var map = Dictionary(uniqueKeysWithValues: ownedBuddies.map { ($0.id, $0) })
        for buddyID in selectedBuddyIDs where map[buddyID] == nil {
            var descriptor = FetchDescriptor<DiveBuddy>(
                predicate: #Predicate<DiveBuddy> { $0.id == buddyID }
            )
            descriptor.fetchLimit = 1
            if let buddy = try? modelContext.fetch(descriptor).first {
                map[buddyID] = buddy
            }
        }
        return map
    }

    static func selectedBuddies(
        ownedBuddies: [DiveBuddy],
        selectedBuddyIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [DiveBuddy] {
        let map = rosterByID(
            ownedBuddies: ownedBuddies,
            selectedBuddyIDs: selectedBuddyIDs,
            modelContext: modelContext
        )
        return selectedBuddyIDs.compactMap { map[$0] }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
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
