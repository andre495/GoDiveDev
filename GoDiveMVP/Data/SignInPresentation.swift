import Foundation

/// Dedicated **Sign in with Apple** screen chrome (onboarding overlay or UI-test root).
enum SignInPresentation: Sendable {
    nonisolated static let backButtonAccessibilityIdentifier = "SignIn.Back"

    nonisolated static func showsBackButton(hasOnBack: Bool) -> Bool {
        hasOnBack
    }
}
