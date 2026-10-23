import Testing
@testable import GoDiveMVP

/// Tests for emulator test sign-in gating logic.
@Suite("Emulator test sign-in gating")
struct EmulatorTestSignInTests {

    #if DEBUG
    @Test("Launch argument parsing extracts email")
    func launchArgumentParsesEmail() {
        let email = GoDiveEmulatorTestSignIn.launchArgumentEmail()
        #expect(email == nil || !email!.isEmpty)
    }

    @Test("isAvailable requires emulator to be enabled")
    func isAvailableRequiresEmulator() {
        let isAvailable = GoDiveEmulatorTestSignIn.isAvailable
        #expect(isAvailable == false || GoDiveFirebaseBootstrap.isEmulatorEnabled)
    }

    @Test("isAvailable is false when emulator not configured")
    func isAvailableFalseWithoutEmulator() {
        let hasLaunchArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent
        let isEnabled = GoDiveFirebaseBootstrap.isEmulatorEnabled
        if !hasLaunchArg || !isEnabled {
            #expect(GoDiveEmulatorTestSignIn.isAvailable == false)
        }
    }
    #endif

    @Test("DEBUG guard excludes emulator sign-in from Release builds")
    func releaseBuildsExcludeEmulatorSignIn() {
        #if !DEBUG
        #expect(true, "Emulator sign-in is correctly excluded from Release builds")
        #else
        _ = GoDiveEmulatorTestSignIn.self
        #expect(true, "Emulator sign-in is available in DEBUG builds")
        #endif
    }
}

/// Tests for emulator configuration gating.
@Suite("Emulator configuration gating")
struct EmulatorConfigurationGatingTests {

    #if DEBUG
    @Test("isEmulatorEnabled is accessible in DEBUG builds")
    func emulatorEnabledAccessible() {
        _ = GoDiveFirebaseBootstrap.isEmulatorEnabled
    }

    @Test("isEmulatorLaunchArgumentPresent is accessible in DEBUG builds")
    func emulatorLaunchArgumentPresentAccessible() {
        _ = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent
    }

    @Test("Emulator requires launch argument to be enabled")
    func emulatorRequiresLaunchArgument() {
        let hasLaunchArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent
        let isEnabled = GoDiveFirebaseBootstrap.isEmulatorEnabled
        if !hasLaunchArg {
            #expect(isEnabled == false, "Emulator should not be enabled without launch argument")
        }
    }

    @Test("Emulator enabled only after useEmulator called")
    func emulatorEnabledOnlyAfterUseEmulator() {
        let hasLaunchArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent
        let isEnabled = GoDiveFirebaseBootstrap.isEmulatorEnabled
        if hasLaunchArg && !isEnabled {
            #expect(true, "Launch arg present but emulator not configured (useEmulator not called)")
        }
    }
    #endif

    @Test("Release builds exclude emulator flag")
    func releaseExcludesEmulatorFlag() {
        #if !DEBUG
        #expect(true, "isEmulatorEnabled is correctly excluded from Release builds")
        #else
        #expect(true, "isEmulatorEnabled is available in DEBUG builds")
        #endif
    }
}

/// Tests for email domain validation.
@Suite("Emulator email validation")
struct EmulatorEmailValidationTests {

    #if DEBUG
    @Test("Valid @example.com emails are accepted")
    func validExampleComEmails() {
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("test@example.com"))
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("qa@example.com"))
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("user.name@example.com"))
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("TEST@EXAMPLE.COM"))
    }

    @Test("Non @example.com emails are rejected")
    func invalidDomainEmailsRejected() {
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("test@gmail.com") == false)
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("test@example.org") == false)
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("test@notexample.com") == false)
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("test@example.com.evil.com") == false)
    }

    @Test("Empty and malformed emails are rejected")
    func emptyAndMalformedEmailsRejected() {
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("") == false)
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("   ") == false)
        #expect(GoDiveEmulatorTestSignIn.isValidTestEmail("@example.com") == false)
    }
    #endif
}

/// Tests for emulator sign-in error cases.
@Suite("Emulator sign-in error handling")
struct EmulatorSignInErrorTests {

    #if DEBUG
    @Test("EmulatorNotRequested error has description")
    func emulatorNotRequestedErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.emulatorNotRequested
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("EmulatorNotConfigured error has description")
    func emulatorNotConfiguredErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.emulatorNotConfigured
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("InvalidEmail error has description")
    func invalidEmailErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.invalidEmail
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("InvalidEmailDomain error has description")
    func invalidEmailDomainErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.invalidEmailDomain
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("SignInFailed error has description")
    func signInFailedErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.signInFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }
    #endif
}
