import Foundation

/// Whether **`ContentView`** (main tab shell) is visible — signed in and past post-sign-up gates.
enum AccountSessionMainShellPresentation: Sendable {
    nonisolated static func showsMainAppShell(
        isSignedIn: Bool,
        showsNewAccountWelcome: Bool,
        showsPostSignUpInterests: Bool,
        showsPostSignUpProfileSetup: Bool,
        showsPostSignUpPermissions: Bool,
        showsPostSignUpImportOffer: Bool,
        showsPostSignUpOnboardingImport: Bool,
        showsSignInCelebration: Bool
    ) -> Bool {
        isSignedIn
            && !showsNewAccountWelcome
            && !showsPostSignUpInterests
            && !showsPostSignUpProfileSetup
            && !showsPostSignUpPermissions
            && !showsPostSignUpImportOffer
            && !showsPostSignUpOnboardingImport
            && !showsSignInCelebration
    }

    /// Mount **`ContentView`** under the celebration overlay so Home is warm before the handoff.
    nonisolated static func shouldMountMainAppShellUnderlay(
        isSignedIn: Bool,
        showsNewAccountWelcome: Bool,
        showsPostSignUpInterests: Bool,
        showsPostSignUpProfileSetup: Bool,
        showsPostSignUpPermissions: Bool,
        showsPostSignUpImportOffer: Bool,
        showsPostSignUpOnboardingImport: Bool,
        showsSignInCelebration: Bool,
        allowsCelebrationShellPrewarm: Bool
    ) -> Bool {
        showsMainAppShell(
            isSignedIn: isSignedIn,
            showsNewAccountWelcome: showsNewAccountWelcome,
            showsPostSignUpInterests: showsPostSignUpInterests,
            showsPostSignUpProfileSetup: showsPostSignUpProfileSetup,
            showsPostSignUpPermissions: showsPostSignUpPermissions,
            showsPostSignUpImportOffer: showsPostSignUpImportOffer,
            showsPostSignUpOnboardingImport: showsPostSignUpOnboardingImport,
            showsSignInCelebration: showsSignInCelebration
        ) || (showsSignInCelebration && allowsCelebrationShellPrewarm)
    }
}
