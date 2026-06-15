import Foundation

struct TripPlannedBuddyMember: Sendable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    let profilePhoto: Data?
    let isOwner: Bool
}

enum TripDetailPlannedBuddyPresentation: Sendable {

    nonisolated static let ownerSubtitle = "You"
    nonisolated static let buddySubtitle = "On this trip"

    nonisolated static func listMembers(
        owner: UserProfile?,
        plannedBuddies: [DiveBuddy]
    ) -> [TripPlannedBuddyMember] {
        shareMembers(owner: owner, plannedBuddies: plannedBuddies)
    }

    nonisolated static func shareMembers(
        owner: UserProfile?,
        plannedBuddies: [DiveBuddy]
    ) -> [TripPlannedBuddyMember] {
        var members: [TripPlannedBuddyMember] = []
        if let owner {
            members.append(
                TripPlannedBuddyMember(
                    id: owner.id,
                    displayName: owner.displayName,
                    profilePhoto: owner.profilePhoto,
                    isOwner: true
                )
            )
        }
        members.append(contentsOf: plannedBuddies.map {
            TripPlannedBuddyMember(
                id: $0.id,
                displayName: $0.displayName,
                profilePhoto: $0.profilePhoto,
                isOwner: false
            )
        })
        return members
    }

    nonisolated static func subtitle(for member: TripPlannedBuddyMember) -> String {
        member.isOwner ? ownerSubtitle : buddySubtitle
    }
}
