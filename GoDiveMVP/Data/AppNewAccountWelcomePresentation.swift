import Foundation

/// Copy and gating for the first-login welcome screen shown before Contacts + Photos prompts.
enum AppNewAccountWelcomePresentation: Sendable {
    nonisolated static let continueButtonTitle = "Continue"

    nonisolated static func shouldPresentWelcome(forNewAccount isNewAccount: Bool) -> Bool {
        isNewAccount && !GoDiveUITestConfiguration.isActive
    }

    nonisolated static func welcomeTitle(displayName: String?) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != UserProfileStore.defaultDisplayName else {
            return "Welcome to GoDive"
        }
        return "Welcome, \(trimmed)"
    }

    nonisolated static let permissionsLeadIn =
        "Next, iOS will ask for two permissions so GoDive can work the way you expect:"

    nonisolated static let contactsPermissionTitle = "Contacts"
    nonisolated static let contactsPermissionBody =
        "Link dive buddies from your address book when you add them to a dive."

    nonisolated static let photosPermissionTitle = "Photos"
    nonisolated static let photosPermissionBody =
        "Attach photos and videos from your library to dives and marine-life sightings."

    nonisolated static let permissionsFooter =
        "You can change these anytime in Settings. Tap Continue when you're ready."
}
