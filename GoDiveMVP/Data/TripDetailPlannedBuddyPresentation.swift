import Foundation
import SwiftUI

/// Caption under a trip buddy avatar (owner label, share status, or invite action).
enum TripBuddyTripShareChrome: Sendable {
    case you
    case invited
    case joined
    case invite
    case none
}

extension TripBuddyTripShareChrome: Equatable {
    nonisolated static func == (lhs: TripBuddyTripShareChrome, rhs: TripBuddyTripShareChrome) -> Bool {
        switch (lhs, rhs) {
        case (.you, .you), (.invited, .invited), (.joined, .joined), (.invite, .invite), (.none, .none):
            true
        default:
            false
        }
    }
}

struct TripPlannedBuddyMember: Sendable, Identifiable {
    let id: UUID
    let displayName: String
    let profilePhoto: Data?
    let isOwner: Bool
    var showsGoDiveUserPin: Bool = false
    var shareChrome: TripBuddyTripShareChrome = .none
}

extension TripPlannedBuddyMember: Equatable {
    nonisolated static func == (lhs: TripPlannedBuddyMember, rhs: TripPlannedBuddyMember) -> Bool {
        lhs.id == rhs.id
            && lhs.displayName == rhs.displayName
            && lhs.profilePhoto == rhs.profilePhoto
            && lhs.isOwner == rhs.isOwner
            && lhs.showsGoDiveUserPin == rhs.showsGoDiveUserPin
            && lhs.shareChrome == rhs.shareChrome
    }
}

enum TripDetailPlannedBuddyPresentation: Sendable {

    nonisolated static let ownerSubtitle = "You"
    /// Share-card caption for planned buddies (trip detail grid no longer uses this).
    nonisolated static let buddySubtitle = "On this trip"
    nonisolated static let invitedBadgeTitle = "Invited"
    nonisolated static let joinedBadgeTitle = "Joined"
    nonisolated static let inviteButtonTitle = "Invite"

    @MainActor
    static func statusBadgeStyle(title: String) -> CertificationPresentation.TypeBadgeStyle {
        CertificationPresentation.TypeBadgeStyle(
            label: title,
            foreground: AppTheme.Colors.accentDeep,
            background: AppTheme.Colors.accentLight.opacity(0.45)
        )
    }

    @MainActor
    static var joinedBadgeStyle: CertificationPresentation.TypeBadgeStyle {
        statusBadgeStyle(title: joinedBadgeTitle)
    }

    nonisolated static func listMembers(
        owner: UserProfile?,
        plannedBuddies: [DiveBuddy],
        trip: DiveTrip? = nil
    ) -> [TripPlannedBuddyMember] {
        shareMembers(owner: owner, plannedBuddies: plannedBuddies, trip: trip)
    }

    nonisolated static func shareMembers(
        owner: UserProfile?,
        plannedBuddies: [DiveBuddy],
        trip: DiveTrip? = nil
    ) -> [TripPlannedBuddyMember] {
        var members: [TripPlannedBuddyMember] = []
        if let owner {
            members.append(
                TripPlannedBuddyMember(
                    id: owner.id,
                    displayName: owner.displayName,
                    profilePhoto: owner.profilePhoto,
                    isOwner: true,
                    showsGoDiveUserPin: false,
                    shareChrome: .you
                )
            )
        }
        members.append(contentsOf: plannedBuddies.map { buddy in
            TripPlannedBuddyMember(
                id: buddy.id,
                displayName: buddy.displayName,
                profilePhoto: buddy.profilePhoto,
                isOwner: false,
                showsGoDiveUserPin: DiveBuddyFriendLinkPresentation.isLinkedFriend(buddy),
                shareChrome: shareChrome(for: buddy, trip: trip)
            )
        })
        return members
    }

    /// Resolves You / Invited / Joined / Invite / none for a roster buddy on a trip.
    nonisolated static func shareChrome(for buddy: DiveBuddy, trip: DiveTrip?) -> TripBuddyTripShareChrome {
        guard DiveBuddyFriendLinkPresentation.isLinkedFriend(buddy),
              let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
        else { return .none }
        guard let trip else { return .invite }
        if DiveTripShareLineagePresentation.hasAcceptedFriend(trip, friendUID: uid) {
            return .joined
        }
        if DiveTripShareLineagePresentation.hasSharedWithFriend(trip, friendUID: uid) {
            return .invited
        }
        return .invite
    }

    nonisolated static func shareChrome(
        forRosterBuddy rosterBuddy: DiveBuddy?,
        trip: DiveTrip?
    ) -> TripBuddyTripShareChrome {
        guard let rosterBuddy else { return .none }
        return shareChrome(for: rosterBuddy, trip: trip)
    }

    /// Owner-only accent label (“You”). Status badges / Invite replace other subtitles.
    nonisolated static func subtitle(for member: TripPlannedBuddyMember) -> String {
        switch member.shareChrome {
        case .you: ownerSubtitle
        case .invited, .joined, .invite, .none: ""
        }
    }

    nonisolated static func statusBadgeTitle(for chrome: TripBuddyTripShareChrome) -> String? {
        switch chrome {
        case .invited: invitedBadgeTitle
        case .joined: joinedBadgeTitle
        case .you, .invite, .none: nil
        }
    }

    nonisolated static func statusBadgeTitle(for member: TripPlannedBuddyMember) -> String? {
        statusBadgeTitle(for: member.shareChrome)
    }

    nonisolated static func accessibilityCaption(for chrome: TripBuddyTripShareChrome) -> String? {
        switch chrome {
        case .you: ownerSubtitle
        case .invited: invitedBadgeTitle
        case .joined: joinedBadgeTitle
        case .invite: inviteButtonTitle
        case .none: nil
        }
    }
}
