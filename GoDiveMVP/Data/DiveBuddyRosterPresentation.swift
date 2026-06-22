import Foundation
import SwiftData

/// Profile roster list + buddy detail copy and shared-dive resolution.
enum DiveBuddyRosterPresentation {
    /// Buddy detail is a fixed **`AppPage`** (no outer scroll); **Dives together** scrolls inside **`ExpandableDetailSection`** when expanded.
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

    static func sharedDiveCount(for buddy: DiveBuddy, ownerProfileID: UUID) -> Int {
        Set(sharedDiveActivities(for: buddy, ownerProfileID: ownerProfileID).map(\.id)).count
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
        numberingActivities: [DiveActivity]
    ) -> [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: sharedDives,
            unitSystem: unitSystem,
            duplicateIds: [],
            useChronologicalNumbers: useChronologicalNumbers,
            numberingActivities: numberingActivities
        )
    }
}
