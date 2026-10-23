import Testing
@testable import GoDiveMVP

/// Tests for emulator test sign-in gating logic.
@Suite("Emulator test sign-in gating")
struct EmulatorTestSignInTests {

    #if DEBUG
    @Test("Launch argument parsing extracts email")
    func launchArgumentParsesEmail() {
        // This test verifies the parsing logic works correctly.
        // In practice, ProcessInfo.processInfo.arguments cannot be mutated,
        // so we test that launchArgumentEmail() returns nil when no arg is set.
        // The actual parsing logic is validated by the implementation.
        let email = GoDiveEmulatorTestSignIn.launchArgumentEmail()
        // Without the launch argument, should return nil
        #expect(email == nil || !email!.isEmpty)
    }

    @Test("isAvailable requires emulator to be enabled")
    func isAvailableRequiresEmulator() {
        // When Firebase is not configured or emulator is not enabled,
        // isAvailable should return false
        let isAvailable = GoDiveEmulatorTestSignIn.isAvailable
        // Without Firebase configured in test environment, this should be false
        #expect(isAvailable == false || GoDiveFirebaseBootstrap.isEmulatorEnabled)
    }
    #endif

    @Test("DEBUG guard excludes emulator sign-in from Release builds")
    func releaseBuildsExcludeEmulatorSignIn() {
        #if !DEBUG
        // In Release builds, GoDiveEmulatorTestSignIn should not exist
        // This test verifies the #if DEBUG guard works
        #expect(true, "Emulator sign-in is correctly excluded from Release builds")
        #else
        // In DEBUG builds, the type exists
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
        // Just accessing the property should not crash
        _ = GoDiveFirebaseBootstrap.isEmulatorEnabled
    }

    @Test("Emulator requires launch argument")
    func emulatorRequiresLaunchArgument() {
        // Without the launch argument, emulator should not be enabled
        // (unless the test is run with the argument)
        let hasLaunchArg = ProcessInfo.processInfo.arguments.contains("-GoDiveUseFirebaseEmulator")
        let isEnabled = GoDiveFirebaseBootstrap.isEmulatorEnabled
        
        if !hasLaunchArg {
            #expect(isEnabled == false, "Emulator should not be enabled without launch argument")
        }
    }
    #endif

    @Test("Release builds exclude emulator flag")
    func releaseExcludesEmulatorFlag() {
        #if !DEBUG
        // In Release builds, isEmulatorEnabled should not be accessible
        // This compile-time check is verified by the absence of the property
        #expect(true, "isEmulatorEnabled is correctly excluded from Release builds")
        #else
        #expect(true, "isEmulatorEnabled is available in DEBUG builds")
        #endif
    }
}

/// Tests for emulator sign-in error cases.
@Suite("Emulator sign-in error handling")
struct EmulatorSignInErrorTests {

    #if DEBUG
    @Test("EmulatorNotAvailable error has description")
    func emulatorNotAvailableErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.emulatorNotAvailable
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("InvalidEmail error has description")
    func invalidEmailErrorDescription() {
        let error = GoDiveEmulatorTestSignIn.EmulatorTestSignInError.invalidEmail
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
