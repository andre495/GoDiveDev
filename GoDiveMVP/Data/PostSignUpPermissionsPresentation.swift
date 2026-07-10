import Foundation

/// Contacts + Photos explainer shown after post-sign-up profile setup and before the import offer.
enum PostSignUpPermissionsPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpPermissions.Root"
    nonisolated static let continueButtonAccessibilityIdentifier = "PostSignUpPermissions.Continue"

    nonisolated static func shouldPresent(isUITest: Bool = GoDiveUITestConfiguration.isActive) -> Bool {
        !isUITest
    }

    nonisolated static let title = "Contacts & Photos"
    nonisolated static let subtitle =
        "Next, iOS will ask for two permissions so GoDive can link buddies and attach dive media."

    nonisolated static var contactsTitle: String {
        AppNewAccountWelcomePresentation.contactsPermissionTitle
    }

    nonisolated static var contactsBody: String {
        AppNewAccountWelcomePresentation.contactsPermissionBody
    }

    nonisolated static var photosTitle: String {
        AppNewAccountWelcomePresentation.photosPermissionTitle
    }

    nonisolated static var photosBody: String {
        AppNewAccountWelcomePresentation.photosPermissionBody
    }

    nonisolated static var footer: String {
        AppNewAccountWelcomePresentation.permissionsFooter
    }

    nonisolated static let continueButtonTitle = AppNewAccountWelcomePresentation.continueButtonTitle
}
