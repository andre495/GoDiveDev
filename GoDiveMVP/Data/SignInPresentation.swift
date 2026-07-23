import Foundation

/// Dedicated **Sign in with Apple** screen chrome (onboarding overlay or UI-test root).
enum SignInPresentation: Sendable {
    nonisolated static let backButtonAccessibilityIdentifier = "SignIn.Back"
    nonisolated static let loggedOutCrashReportsLinkTitle = "Diagnostic reports"
    nonisolated static let loggedOutCrashReportsAccessibilityIdentifier = "SignIn.CrashReports"

    nonisolated static func showsBackButton(hasOnBack: Bool) -> Bool {
        hasOnBack
    }
}
