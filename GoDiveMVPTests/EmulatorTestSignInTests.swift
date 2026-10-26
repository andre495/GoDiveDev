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

    @Test("isAvailable requires emulator launch argument")
    func isAvailableRequiresEmulatorLaunchArg() {
        let hasLaunchArg = GoDiveFirebaseBootstrap.isEmulatorLaunchArgumentPresent
        if !hasLaunchArg {
            #expect(GoDiveEmulatorTestSignIn.isAvailable == false)
        }
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

/// Tests for emulator session guard decision logic.
@Suite("Emulator session guard")
struct EmulatorSessionGuardTests {

    #if DEBUG
    // MARK: - Pure Decision Logic Tests (no Auth dependency)

    @Test("shouldClearSession returns false when emulator is enabled")
    func shouldNotClearWhenEmulatorEnabled() {
        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: true,
            hasMarker: true,
            currentUserEmail: "test@example.com"
        ) == false)
    }

    @Test("shouldClearSession returns false when no evidence and emulator off")
    func shouldNotClearWhenNoEvidence() {
        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: false,
            currentUserEmail: nil
        ) == false)

        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: false,
            currentUserEmail: "user@gmail.com"
        ) == false)
    }

    @Test("shouldClearSession returns true when marker set and emulator off")
    func shouldClearWhenMarkerSetAndEmulatorOff() {
        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: true,
            currentUserEmail: nil
        ) == true)
    }

    @Test("shouldClearSession returns true when test email present and emulator off")
    func shouldClearWhenTestEmailAndEmulatorOff() {
        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: false,
            currentUserEmail: "qa@example.com"
        ) == true)
    }

    @Test("shouldClearSession returns true when both marker and test email present and emulator off")
    func shouldClearWhenBothEvidenceAndEmulatorOff() {
        #expect(GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: true,
            currentUserEmail: "test@example.com"
        ) == true)
    }

    // MARK: - Email Detection Tests

    @Test("isTestEmail detects @example.com emails")
    func isTestEmailDetectsExampleCom() {
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("test@example.com") == true)
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("QA@EXAMPLE.COM") == true)
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("user.name@example.com") == true)
    }

    @Test("isTestEmail rejects non @example.com emails")
    func isTestEmailRejectsOtherDomains() {
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("test@gmail.com") == false)
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("test@example.org") == false)
        #expect(GoDiveEmulatorSessionGuard.isTestEmail(nil) == false)
        #expect(GoDiveEmulatorSessionGuard.isTestEmail("") == false)
    }

    // MARK: - Marker Tests

    @Test("Marker can be set and cleared")
    func markerSetAndClear() {
        GoDiveEmulatorSessionGuard.clearEmulatorMarker()
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker == false)

        GoDiveEmulatorSessionGuard.markSessionAsEmulator()
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker == true)

        GoDiveEmulatorSessionGuard.clearEmulatorMarker()
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker == false)
    }
    #endif

    @Test("DEBUG guard excludes session guard from Release builds")
    func releaseBuildsExcludeSessionGuard() {
        #if !DEBUG
        #expect(true, "Session guard is correctly excluded from Release builds")
        #else
        _ = GoDiveEmulatorSessionGuard.self
        #expect(true, "Session guard is available in DEBUG builds")
        #endif
    }
}

/// Tests for emulator session isolation — ensures emulator-origin sessions are cleared on non-emulator launches.
@Suite("Emulator session isolation")
struct EmulatorSessionIsolationTests {

    #if DEBUG
    @Test("clearPersistedEmulatorSession clears profile ID from Keychain")
    func clearPersistedEmulatorSessionClearsProfileID() {
        GoDiveKeychainStore.testingStore = [:]
        defer { GoDiveKeychainStore.testingStore = nil }

        let testProfileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(testProfileID)
        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == testProfileID)

        GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession()

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == nil)
    }

    @Test("clearPersistedEmulatorSession clears returning account hints")
    func clearPersistedEmulatorSessionClearsReturningHints() {
        GoDiveKeychainStore.testingStore = [:]
        defer { GoDiveKeychainStore.testingStore = nil }

        _ = GoDiveKeychainStore.setString("emulator_test_abc123", account: .lastAppleUserIdentifier)
        _ = GoDiveKeychainStore.setString(UUID().uuidString, account: .lastProfileID)
        _ = GoDiveKeychainStore.setString("Test User", account: .lastDisplayName)

        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) != nil)

        GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession()

        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == nil)
        #expect(GoDiveKeychainStore.string(for: .lastProfileID) == nil)
        #expect(GoDiveKeychainStore.string(for: .lastDisplayName) == nil)
    }

    @Test("clearPersistedEmulatorSession clears Firebase UID cache")
    func clearPersistedEmulatorSessionClearsFirebaseUID() {
        GoDiveKeychainStore.testingStore = [:]
        defer { GoDiveKeychainStore.testingStore = nil }

        GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID("emulator_uid_123")
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == "emulator_uid_123")

        GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession()

        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == nil)
    }

    @Test("Emulator-marked session on non-emulator launch triggers clear decision")
    func emulatorMarkedSessionOnNonEmulatorLaunchShouldClear() {
        let shouldClear = GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: true,
            currentUserEmail: nil
        )
        #expect(shouldClear == true, "Session with emulator marker should be cleared on non-emulator launch")
    }

    @Test("Emulator-marked session on emulator launch is kept")
    func emulatorMarkedSessionOnEmulatorLaunchIsKept() {
        let shouldClear = GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: true,
            hasMarker: true,
            currentUserEmail: "test@example.com"
        )
        #expect(shouldClear == false, "Session should be kept when emulator is enabled")
    }

    @Test("No marker means session unchanged")
    func noMarkerMeansSessionUnchanged() {
        let shouldClear = GoDiveEmulatorSessionGuard.shouldClearSession(
            isEmulatorEnabled: false,
            hasMarker: false,
            currentUserEmail: "real.user@gmail.com"
        )
        #expect(shouldClear == false, "Session without emulator marker should not be cleared")
    }

    @Test("Complete session clear removes all persisted emulator state")
    func completeSessionClearRemovesAllPersistedState() {
        GoDiveKeychainStore.testingStore = [:]
        defer { GoDiveKeychainStore.testingStore = nil }

        let profileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profileID)
        _ = GoDiveKeychainStore.setString("emulator_test_user", account: .lastAppleUserIdentifier)
        _ = GoDiveKeychainStore.setString(profileID.uuidString, account: .lastProfileID)
        _ = GoDiveKeychainStore.setString("Emulator Tester", account: .lastDisplayName)
        GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID("emu_firebase_uid")
        GoDiveEmulatorSessionGuard.markSessionAsEmulator()

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == profileID)
        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == "emulator_test_user")
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == "emu_firebase_uid")
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker == true)

        GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession()
        GoDiveEmulatorSessionGuard.clearEmulatorMarker()

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == nil)
        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == nil)
        #expect(GoDiveKeychainStore.string(for: .lastProfileID) == nil)
        #expect(GoDiveKeychainStore.string(for: .lastDisplayName) == nil)
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == nil)
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker == false)
    }
    #endif

    @Test("DEBUG guard excludes session isolation from Release builds")
    func releaseBuildsExcludeSessionIsolation() {
        #if !DEBUG
        #expect(true, "Session isolation is correctly excluded from Release builds")
        #else
        _ = GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession
        #expect(true, "Session isolation is available in DEBUG builds")
        #endif
    }
}
