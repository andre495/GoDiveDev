import Foundation

/// Post–Sign in with Apple profile setup for brand-new accounts (photo, DAN, cert, preview).
enum PostSignUpProfileSetupPresentation: Sendable {
    nonisolated static let rootAccessibilityIdentifier = "PostSignUpProfileSetup.Root"

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

    nonisolated static func stepTitle(_ step: Step) -> String {
        switch step {
        case .profilePhoto:
            "Add a profile photo"
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
            "Help buddies recognize you in the logbook."
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
        case .danInsurance, .certification:
            "Skip for now"
        case .profilePhoto, .preview:
            nil
        }
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
