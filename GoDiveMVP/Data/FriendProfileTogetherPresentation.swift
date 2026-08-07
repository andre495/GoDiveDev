import Foundation
import SwiftData

/// Resolves owner “dives together” with a GoDive friend (linked roster buddy).
enum FriendProfileTogetherPresentation: Sendable {

    @MainActor
    static func linkedBuddy(
        friendUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> DiveBuddy? {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return nil }
        let descriptor = FetchDescriptor<DiveBuddy>(
            predicate: #Predicate<DiveBuddy> {
                $0.ownerProfileID == ownerProfileID && $0.linkedFirebaseUID == uid
            }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    @MainActor
    static func togetherDiveActivities(
        friendUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveActivity] {
        guard let buddy = linkedBuddy(
            friendUID: friendUID,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        ) else { return [] }
        return DiveBuddyRosterPresentation.sharedDiveActivities(
            for: buddy,
            ownerProfileID: ownerProfileID
        )
    }

    nonisolated static func togetherActivityIDs(from activities: [DiveActivity]) -> Set<UUID> {
        Set(activities.map(\.id))
    }
}
