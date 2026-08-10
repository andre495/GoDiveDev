import Foundation
import SwiftData

/// Profile roster list + buddy detail copy and shared-dive resolution.
enum DiveBuddyRosterPresentation {
    /// Buddy detail uses **`AppHeaderlessPage`** with a tagged-media hero and a horizontal content pager.
    static let buddyDetailUsesScrollContainer = false

    nonisolated static func rosterCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No buddies"
        case 1:
            return "1 buddy"
        default:
            return "\(count) buddies"
        }
    }

    nonisolated static func listSubtitle(sharedDiveCount: Int) -> String {
        sharedDiveCountLabel(sharedDiveCount)
    }

    nonisolated static func sharedDiveCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No dives together"
        case 1:
            return "1 dive together"
        default:
            return "\(count) dives together"
        }
    }

    /// Owned dives this buddy is tagged on, newest **`startTime`** first.
    static func sharedDiveActivities(for buddy: DiveBuddy, ownerProfileID: UUID) -> [DiveActivity] {
        sharedDiveActivities(from: buddy.diveParticipations, ownerProfileID: ownerProfileID)
    }

    /// Same as **`sharedDiveActivities(for:ownerProfileID:)`** using pre-fetched buddy tags.
    static func sharedDiveActivities(from tags: [DiveBuddyTag], ownerProfileID: UUID) -> [DiveActivity] {
        let dives = tags.compactMap(\.dive).filter { dive in
            dive.ownerProfileID == ownerProfileID
        }
        return dives.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime > rhs.startTime }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Counts owned shared dives without sorting the activity list (list rows only need the count).
    static func sharedDiveCount(for buddy: DiveBuddy, ownerProfileID: UUID) -> Int {
        var ids = Set<UUID>()
        for tag in buddy.diveParticipations {
            guard let dive = tag.dive, dive.ownerProfileID == ownerProfileID else { continue }
            ids.insert(dive.id)
        }
        return ids.count
    }

    /// One-shot count map for **Buddies** list — avoids walking tags once per body evaluation.
    static func sharedDiveCountsByBuddyID(
        for buddies: [DiveBuddy],
        ownerProfileID: UUID
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        result.reserveCapacity(buddies.count)
        for buddy in buddies {
            result[buddy.id] = sharedDiveCount(for: buddy, ownerProfileID: ownerProfileID)
        }
        return result
    }

    /// List-safe counts from denormalized **`DiveBuddyTag`** fields — no **`diveParticipations`** / dive faults.
    @MainActor
    static func sharedDiveCountsByBuddyID(
        buddyIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> [UUID: Int] {
        guard !buddyIDs.isEmpty else { return [:] }
        let tags = (try? modelContext.fetch(FetchDescriptor<DiveBuddyTag>())) ?? []
        var diveIDsByBuddy: [UUID: Set<UUID>] = [:]
        for tag in tags {
            guard let buddyID = tag.buddyID,
                  buddyIDs.contains(buddyID),
                  let diveID = tag.diveActivityID
            else { continue }
            diveIDsByBuddy[buddyID, default: []].insert(diveID)
        }
        var result: [UUID: Int] = [:]
        result.reserveCapacity(buddyIDs.count)
        for buddyID in buddyIDs {
            result[buddyID] = diveIDsByBuddy[buddyID]?.count ?? 0
        }
        return result
    }

    /// Inputs for refreshing cached logbook rows on buddy detail without recomputing on every expand tap.
    struct SharedDiveListRefreshToken: Equatable, Sendable {
        let buddyID: UUID
        let sharedDiveIDs: [UUID]
        let unitSystem: DiveDisplayUnitSystem
        let useChronologicalNumbers: Bool
        let numberingActivityCount: Int
    }

    static func sharedDiveListRefreshToken(
        buddyID: UUID,
        sharedDives: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        numberingActivities: [DiveActivity]
    ) -> SharedDiveListRefreshToken {
        SharedDiveListRefreshToken(
            buddyID: buddyID,
            sharedDiveIDs: sharedDives.map(\.id),
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivityCount: numberingActivities.count
        )
    }

    static func sharedDiveRowDisplayData(
        sharedDives: [DiveActivity],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool,
        numberingActivities: [DiveActivity] = [],
        numberingRows: [DiveActivityDiveNumbering.NumberingRow] = []
    ) -> [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: sharedDives,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: numberingActivities.isEmpty ? nil : numberingActivities,
            numberingRows: numberingRows.isEmpty ? nil : numberingRows
        )
    }
}
