import Foundation

/// Optional import-your-log slide after post-sign-up profile setup (MacDive / UDDF bulk).
enum PostSignUpImportOfferPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpImportOffer.Root"
    nonisolated static let importButtonAccessibilityIdentifier = "PostSignUpImportOffer.Import"
    nonisolated static let skipButtonAccessibilityIdentifier = "PostSignUpImportOffer.Skip"

    nonisolated static let title = "Bring your old dives"
    nonisolated static let subtitle =
        "If you used MacDive on your computer, export your log as a UDDF file and import every dive at once in GoDive."
    nonisolated static let macDiveHintTitle = "MacDive users"
    nonisolated static let macDiveHintBody =
        "Export from MacDive, save the .uddf file to your iPhone, then choose MacDive / Universal import in GoDive. We walk you through each step."
    nonisolated static let importButtonTitle = "Import dives"
    nonisolated static let skipButtonTitle = "Skip for now"

    nonisolated static func shouldPresentImportOffer(
        for profile: UserProfile,
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        guard !isUITest else { return false }
        return PostSignUpProfileSetupPresentation.requiresDiveProfileSetup(for: profile)
    }
}
