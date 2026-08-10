import CoreGraphics
import Foundation

/// Creates a friend invite and opens Messages for a non-GoDive roster buddy.
enum DiveBuddyInviteSMSPresentation: Sendable {
    nonisolated static let detailAccessibilityIdentifier = "DiveBuddyDetails.Invite"
    nonisolated static let plusSystemImage = "plus"

    /// Opaque **+** badge diameter on the buddy-detail avatar (matches photo-editor camera badge scale).
    nonisolated static func avatarPlusBadgeSideLength(
        avatarDiameter: CGFloat = DiveBuddyDetailPresentation.profileAvatarDiameter
    ) -> CGFloat {
        max(32, avatarDiameter * 0.27)
    }

    enum Outcome: Equatable, Sendable {
        case presented
        case failed(message: String)
    }

    /// Creates an invite URL, then presents Messages with the buddy’s contact phone when linked
    /// (`contactsIdentifier`); otherwise an empty recipient field and the invite body.
    @MainActor
    static func presentInviteSMS(
        buddyDisplayName: String,
        contactsIdentifier: String?,
        isNetworkConnected: Bool
    ) async -> Outcome {
        guard isNetworkConnected else {
            return .failed(message: GoDiveFriendsPresentation.firebaseUnavailableMessage)
        }

        let result = await GoDiveFriendGraphService.createInvite()
        switch result {
        case .success(let pair):
            let recipients = DiveBuddyContactSMSPresentation.smsRecipients(
                contactsIdentifier: contactsIdentifier
            )
            let body = BuddiesListPresentation.smsBody(
                inviteURL: pair.url,
                buddyDisplayName: buddyDisplayName
            )
            FriendInviteSMSComposePresentation.present(recipients: recipients, body: body)
            return .presented
        case .failure(let failure):
            return .failed(message: failure.message)
        }
    }
}
