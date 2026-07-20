import Foundation

/// Post–Sign in with Apple activity picker when the user skipped logged-out welcome interests
/// (**Already have an account? Sign in** → brand-new Apple ID).
enum PostSignUpInterestsPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpInterests.Root"
    nonisolated static let continueAccessibilityIdentifier = "PostSignUpInterests.Continue"

    nonisolated static let title = "What do you do in the water?"
    nonisolated static let subtitle = "Pick one or more — you can change this later in Profile."
    nonisolated static let continueTitle = "Continue"

    /// Show when signup chrome is running and welcome never saved a pending activity selection.
    nonisolated static func shouldPresent(
        hadPendingWelcomeInterests: Bool,
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        !hadPendingWelcomeInterests && !isUITest
    }
}
