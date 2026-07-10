import Foundation

/// Read-only copy for the **Profile** header.
enum ProfilePresentation: Sendable {
    static func danInsuranceLabel(_ memberNumber: String) -> String {
        "DAN \(memberNumber)"
    }

    static func diveActivityCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No dives logged"
        case 1:
            return "1 dive"
        default:
            return "\(count) dives"
        }
    }

    static func certificationCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No certifications"
        case 1:
            return "1 certification"
        default:
            return "\(count) certifications"
        }
    }

    static func equipmentItemCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No gear"
        case 1:
            return "1 item"
        default:
            return "\(count) items"
        }
    }

    static func diveBuddyRosterCountLabel(_ count: Int) -> String {
        DiveBuddyRosterPresentation.rosterCountLabel(count)
    }

    static func tripCountLabel(_ count: Int) -> String {
        switch count {
        case 0:
            return "No trips"
        case 1:
            return "1 trip"
        default:
            return "\(count) trips"
        }
    }

    /// Confirmation alert when the user taps **Sign out** on Profile.
    nonisolated static let signOutConfirmationTitle = "Sign out?"
    nonisolated static let signOutConfirmationMessage =
        "Are you sure you want to sign out? Your dives stay on this device for this Apple ID."
    nonisolated static let signOutConfirmButtonTitle = "Sign out"
    nonisolated static let signOutCancelButtonTitle = "Cancel"
}

/// Layout for **Profile** destination tiles (Certifications, Equipment Locker, Dive Buddies, Trips).
enum ProfileDestinationTilePresentation: Sendable {
    nonisolated static let iconPointSize: CGFloat = 22
    nonisolated static let iconSlotWidth: CGFloat = 28
    nonisolated static let cornerRadius: CGFloat = 14
    nonisolated static let verticalPadding: CGFloat = 10
    nonisolated static let horizontalPadding: CGFloat = 14
    nonisolated static let textStackSpacing: CGFloat = 2
    /// Fixed height so every tile matches regardless of title length.
    nonisolated static let tileHeight: CGFloat = 54
}
