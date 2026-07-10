import Foundation

/// Post–Sign in with Apple profile setup for brand-new accounts (photo, DAN, cert, preview).
enum PostSignUpProfileSetupPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpProfileSetup.Root"
    nonisolated static let backButtonAccessibilityIdentifier = "PostSignUpProfileSetup.Back"

    enum Step: Equatable, Sendable {
        case profilePhoto
        case danInsurance
        case certification
        case preview
    }

    nonisolated static func shouldPresentSetup(
        isNewAccount: Bool,
        isUITest: Bool = GoDiveUITestConfiguration.isActive
    ) -> Bool {
        isNewAccount && !isUITest
    }

    nonisolated static func steps(for profile: UserProfile) -> [Step] {
        var result: [Step] = [.profilePhoto]
        if requiresDiveProfileSetup(for: profile) {
            result.append(.danInsurance)
            result.append(.certification)
        }
        result.append(.preview)
        return result
    }

    nonisolated static func requiresDiveProfileSetup(for profile: UserProfile) -> Bool {
        profile.doesScubaDiving || profile.doesFreeDiving
    }

    nonisolated static func selectedInterestKinds(for profile: UserProfile) -> [UserOnboardingActivityKind] {
        UserOnboardingActivityKind.allCases.filter { kind in
            switch kind {
            case .scubaDiving: profile.doesScubaDiving
            case .freeDiving: profile.doesFreeDiving
            case .snorkeling: profile.doesSnorkeling
            }
        }
    }

    nonisolated static func stepTitle(_ step: Step, displayName: String) -> String {
        switch step {
        case .profilePhoto:
            "Welcome, \(displayName)"
        case .danInsurance:
            "Add DAN insurance"
        case .certification:
            "Add a certification"
        case .preview:
            "Welcome"
        }
    }

    nonisolated static func stepSubtitle(_ step: Step) -> String {
        switch step {
        case .profilePhoto:
            "Add a profile photo"
        case .danInsurance:
            "Optional — store your DAN member number on your profile."
        case .certification:
            "Snap your card or enter agency details — you can add more later."
        case .preview:
            "Let's Dive In"
        }
    }

    nonisolated static func continueTitle(for step: Step) -> String {
        switch step {
        case .preview:
            "Let's dive in"
        default:
            "Continue"
        }
    }

    nonisolated static func skipTitle(for step: Step) -> String? {
        switch step {
        case .profilePhoto, .danInsurance, .certification:
            "Skip for now"
        case .preview:
            nil
        }
    }

    /// Optional steps hide **Continue** until the user has entered data; preview always shows the primary CTA.
    nonisolated static func showsContinueButton(
        for step: Step,
        hasProfilePhoto: Bool,
        danInsuranceNumber: String,
        certificationFormCanSave: Bool
    ) -> Bool {
        switch step {
        case .profilePhoto:
            hasProfilePhoto
        case .danInsurance:
            !danInsuranceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .certification:
            certificationFormCanSave
        case .preview:
            true
        }
    }

    nonisolated static func showsBackButton(stepIndex: Int) -> Bool {
        stepIndex > 0
    }

    nonisolated static func stepAccessibilityIdentifier(_ step: Step) -> String {
        switch step {
        case .profilePhoto: "PostSignUpProfileSetup.Step.ProfilePhoto"
        case .danInsurance: "PostSignUpProfileSetup.Step.DanInsurance"
        case .certification: "PostSignUpProfileSetup.Step.Certification"
        case .preview: "PostSignUpProfileSetup.Step.Preview"
        }
    }
}
