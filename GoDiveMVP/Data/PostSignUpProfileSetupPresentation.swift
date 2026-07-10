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

    /// Pause rising bubbles only on the heavy certification form — DAN keeps motion during step handoff.
    nonisolated static func shouldPauseBubbleAnimation(for step: Step) -> Bool {
        if case .certification = step { return true }
        return false
    }

    /// DAN / certification use a flat layout (no **`ScrollView`**) to avoid scroll transition jank.
    nonisolated static func usesFlatStepLayout(for step: Step) -> Bool {
        switch step {
        case .danInsurance, .certification:
            return true
        case .profilePhoto, .preview:
            return false
        }
    }

    nonisolated static let stepTransitionDuration: Double = 0.15

    nonisolated static var stepTransitionNanoseconds: UInt64 {
        UInt64(stepTransitionDuration * 1_000_000_000)
    }

    /// Keep bubbles running through the opacity crossfade, then pause for certification typing.
    nonisolated static func bubblePauseDelayNanoseconds(whenEntering step: Step) -> UInt64? {
        guard shouldPauseBubbleAnimation(for: step) else { return nil }
        return stepTransitionNanoseconds + 30_000_000
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
    /// Profile photo auto-advances after crop save — no **Continue** on that step.
    nonisolated static func showsContinueButton(
        for step: Step,
        hasProfilePhoto: Bool,
        danShowsContinue: Bool,
        certificationFormCanSave: Bool
    ) -> Bool {
        switch step {
        case .profilePhoto:
            false
        case .danInsurance:
            danShowsContinue
        case .certification:
            certificationFormCanSave
        case .preview:
            true
        }
    }

    /// **Skip** hides while the certification keyboard is up — it returns in the bottom chrome after dismiss.
    nonisolated static func showsSkipInBottomChrome(
        for step: Step,
        isCertificationKeyboardVisible: Bool
    ) -> Bool {
        guard skipTitle(for: step) != nil else { return false }
        if case .certification = step, isCertificationKeyboardVisible {
            return false
        }
        return true
    }

    /// **Continue** moves to the keyboard accessory row on the certification step while typing.
    nonisolated static func showsContinueInBottomChrome(
        for step: Step,
        hasProfilePhoto: Bool,
        danShowsContinue: Bool,
        certificationFormCanSave: Bool,
        isCertificationKeyboardVisible: Bool
    ) -> Bool {
        guard showsContinueButton(
            for: step,
            hasProfilePhoto: hasProfilePhoto,
            danShowsContinue: danShowsContinue,
            certificationFormCanSave: certificationFormCanSave
        ) else { return false }
        if case .certification = step, isCertificationKeyboardVisible {
            return false
        }
        return true
    }

    nonisolated static func showsContinueInCertificationKeyboardToolbar(
        certificationFormCanSave: Bool,
        isCertificationKeyboardVisible: Bool
    ) -> Bool {
        isCertificationKeyboardVisible && certificationFormCanSave
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

    /// True once the user adds card photos or enters any certification field text.
    nonisolated static func certificationStepHasStartedEntry(form: CertificationFormValues) -> Bool {
        if form.certFrontPicture != nil || form.certBackPicture != nil {
            return true
        }

        let trimmedFields = [
            form.certName,
            form.agency,
            form.certNumber,
            form.instructor,
            form.instructorNumber,
            form.diveShop,
            form.diveShopNumber,
        ]
        return trimmedFields.contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Certification onboarding collapses instructional chrome once entry begins or a field is focused.
    nonisolated static func certificationStepUsesExpandedLayout(
        form: CertificationFormValues,
        isTextFieldFocused: Bool
    ) -> Bool {
        certificationStepHasStartedEntry(form: form) || isTextFieldFocused
    }
}
