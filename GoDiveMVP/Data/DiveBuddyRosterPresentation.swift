import Foundation
import SwiftData

/// Profile roster list + buddy detail copy and shared-dive resolution.
enum DiveBuddyRosterPresentation {

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
        let dives = buddy.diveParticipations.compactMap(\.dive).filter { dive in
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
}
