import Foundation

/// Detects newly added GoDive friends on a trip who should get a share offer.
enum DiveTripShareOfferPresentation: Sendable {
    struct Candidate: Equatable, Sendable, Identifiable {
        var id: String { friendUID }
        var buddyID: UUID
        var friendUID: String
        var displayName: String
    }

    /// Friends newly added to the trip who are not already shared with.
    nonisolated static func candidates(
        previousBuddyIDs: Set<UUID>,
        newBuddyIDs: Set<UUID>,
        rosterByID: [UUID: DiveBuddy],
        trip: DiveTrip
    ) -> [Candidate] {
        let added = newBuddyIDs.subtracting(previousBuddyIDs)
        guard !added.isEmpty else { return [] }

        var result: [Candidate] = []
        result.reserveCapacity(added.count)
        for buddyID in added.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let buddy = rosterByID[buddyID],
                  let friendUID = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
            else { continue }
            if DiveTripShareLineagePresentation.hasSharedWithFriend(trip, friendUID: friendUID) {
                continue
            }
            result.append(
                Candidate(
                    buddyID: buddyID,
                    friendUID: friendUID,
                    displayName: buddy.displayName
                )
            )
        }
        return result
    }

    nonisolated static func confirmationTitle(displayName: String) -> String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "this buddy" : name
        return "Share this trip with \(label)?"
    }

    nonisolated static let shareButtonTitle = "Share"
    nonisolated static let declineButtonTitle = "Not Now"
    nonisolated static let confirmationMessage =
        "They’ll get an invite to add a copy of this trip. You stay the owner of trip details."
}
