import Foundation

/// UDDF import options + optional MacDive guide during post-sign-up onboarding (before bubble celebration).
enum PostSignUpOnboardingImportPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpOnboardingImport.Root"
    nonisolated static let optionsAccessibilityIdentifier = "PostSignUpOnboardingImport.Options"
    nonisolated static let skipButtonAccessibilityIdentifier = "PostSignUpOnboardingImport.Skip"
    nonisolated static let skipButtonTitle = "Skip"
}
