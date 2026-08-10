import Foundation

/// Copy + chrome for trip-share invite accept/decline and edit locks.
enum DiveTripShareInvitePresentation: Sendable {
    nonisolated static let pendingBannerTitle = "Trip invite"
    nonisolated static let acceptButtonTitle = "Accept"
    nonisolated static let declineButtonTitle = "Decline"
    nonisolated static let inviteeCannotEditMessage =
        "Only the trip creator can change dates, countries, and planned sites."
    nonisolated static let acceptOverlapMessagePrefix = "These dates overlap"
    nonisolated static let pendingListBadgeTitle = "Invite"

    nonisolated static func pendingBannerMessage(sharerDisplayName: String?) -> String {
        let name = sharerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty {
            return "Accept to keep this trip in your planner, or decline to remove it."
        }
        return "\(name) shared this trip with you. Accept to keep it, or decline to remove it."
    }

    nonisolated static func acceptOverlapMessage(conflictTitle: String) -> String {
        "\(acceptOverlapMessagePrefix) “\(conflictTitle)”. Adjust or remove that trip before accepting."
    }

    nonisolated static let acceptErrorTitle = "Couldn’t accept trip"
    nonisolated static let declineErrorTitle = "Couldn’t decline trip"
}
