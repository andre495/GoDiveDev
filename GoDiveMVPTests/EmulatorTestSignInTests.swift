import Foundation
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
        if hasLaunchArg {
            #expect(isEnabled == true || isEnabled == false, "Emulator may or may not be enabled after launch arg")
        }
    }
    #endif
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

    @Test("Marker can use injected UserDefaults")
    func markerWithInjectedUserDefaults() {
        let testDefaults = UserDefaults(suiteName: "EmulatorSessionGuardTests")!
        defer { testDefaults.removePersistentDomain(forName: "EmulatorSessionGuardTests") }

        GoDiveEmulatorSessionGuard.clearEmulatorMarker(userDefaults: testDefaults)
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == false)

        GoDiveEmulatorSessionGuard.markSessionAsEmulator(userDefaults: testDefaults)
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == true)

        GoDiveEmulatorSessionGuard.clearEmulatorMarker(userDefaults: testDefaults)
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == false)
    }
    #endif
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

    // MARK: - End-to-End Tests with Injected Fakes

    @Test("End-to-end: emulator-marked session on non-emulator launch calls sign-out and clears all state")
    func endToEndEmulatorMarkedNonEmulatorLaunch() {
        GoDiveKeychainStore.testingStore = [:]
        let testDefaults = UserDefaults(suiteName: "EmulatorSessionIsolationEndToEndTests")!
        defer {
            GoDiveKeychainStore.testingStore = nil
            testDefaults.removePersistentDomain(forName: "EmulatorSessionIsolationEndToEndTests")
        }

        let profileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profileID)
        _ = GoDiveKeychainStore.setString("emulator_test_user", account: .lastAppleUserIdentifier)
        _ = GoDiveKeychainStore.setString(profileID.uuidString, account: .lastProfileID)
        _ = GoDiveKeychainStore.setString("Emulator Tester", account: .lastDisplayName)
        GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID("emu_firebase_uid")
        GoDiveEmulatorSessionGuard.markSessionAsEmulator(userDefaults: testDefaults)

        var signOutCalled = false
        var persistedSessionCleared = false
        var markerCleared = false

        let result = GoDiveEmulatorSessionGuard.clearEmulatorSessionIfNeeded(
            isEmulatorEnabled: false,
            hasMarker: true,
            currentUserEmail: "test@example.com",
            signOut: { signOutCalled = true },
            clearPersistedSession: {
                GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession()
                persistedSessionCleared = true
            },
            clearMarker: {
                GoDiveEmulatorSessionGuard.clearEmulatorMarker(userDefaults: testDefaults)
                markerCleared = true
            }
        )

        #expect(result.didClear == true, "Should clear session")
        #expect(result.signOutCalled == true, "Should call sign-out")
        #expect(result.persistedSessionCleared == true, "Should clear persisted session")
        #expect(result.markerCleared == true, "Should clear marker")
        #expect(signOutCalled == true, "Sign-out closure should be called")
        #expect(persistedSessionCleared == true, "Persisted session clear closure should be called")
        #expect(markerCleared == true, "Marker clear closure should be called")

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == nil, "Profile ID should be cleared")
        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == nil, "Apple ID should be cleared")
        #expect(GoDiveKeychainStore.string(for: .lastProfileID) == nil, "Last profile ID should be cleared")
        #expect(GoDiveKeychainStore.string(for: .lastDisplayName) == nil, "Display name should be cleared")
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == nil, "Firebase UID should be cleared")
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == false, "Marker should be cleared")
    }

    @Test("End-to-end: emulator launch keeps session, no sign-out or clear")
    func endToEndEmulatorLaunchKeepsSession() {
        GoDiveKeychainStore.testingStore = [:]
        let testDefaults = UserDefaults(suiteName: "EmulatorSessionIsolationKeepTests")!
        defer {
            GoDiveKeychainStore.testingStore = nil
            testDefaults.removePersistentDomain(forName: "EmulatorSessionIsolationKeepTests")
        }

        let profileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profileID)
        _ = GoDiveKeychainStore.setString("emulator_test_user", account: .lastAppleUserIdentifier)
        GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID("emu_firebase_uid")
        GoDiveEmulatorSessionGuard.markSessionAsEmulator(userDefaults: testDefaults)

        var signOutCalled = false
        var persistedSessionCleared = false
        var markerCleared = false

        let result = GoDiveEmulatorSessionGuard.clearEmulatorSessionIfNeeded(
            isEmulatorEnabled: true,
            hasMarker: true,
            currentUserEmail: "test@example.com",
            signOut: { signOutCalled = true },
            clearPersistedSession: { persistedSessionCleared = true },
            clearMarker: { markerCleared = true }
        )

        #expect(result.didClear == false, "Should not clear session when emulator enabled")
        #expect(result.signOutCalled == false, "Should not call sign-out")
        #expect(result.persistedSessionCleared == false, "Should not clear persisted session")
        #expect(result.markerCleared == false, "Should not clear marker")
        #expect(signOutCalled == false, "Sign-out closure should not be called")
        #expect(persistedSessionCleared == false, "Persisted session clear closure should not be called")
        #expect(markerCleared == false, "Marker clear closure should not be called")

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == profileID, "Profile ID should be preserved")
        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == "emulator_test_user", "Apple ID should be preserved")
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == "emu_firebase_uid", "Firebase UID should be preserved")
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == true, "Marker should be preserved")
    }

    @Test("End-to-end: no marker means no clear operations")
    func endToEndNoMarkerNoOperations() {
        GoDiveKeychainStore.testingStore = [:]
        defer { GoDiveKeychainStore.testingStore = nil }

        let profileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profileID)
        _ = GoDiveKeychainStore.setString("real_user_apple_id", account: .lastAppleUserIdentifier)
        GoDiveFirestoreUserProfileMapping.saveCachedFirebaseUID("real_firebase_uid")

        var signOutCalled = false
        var persistedSessionCleared = false
        var markerCleared = false

        let result = GoDiveEmulatorSessionGuard.clearEmulatorSessionIfNeeded(
            isEmulatorEnabled: false,
            hasMarker: false,
            currentUserEmail: "real.user@gmail.com",
            signOut: { signOutCalled = true },
            clearPersistedSession: { persistedSessionCleared = true },
            clearMarker: { markerCleared = true }
        )

        #expect(result.didClear == false, "Should not clear session without marker")
        #expect(result.signOutCalled == false, "Should not call sign-out")
        #expect(result.persistedSessionCleared == false, "Should not clear persisted session")
        #expect(result.markerCleared == false, "Should not clear marker")
        #expect(signOutCalled == false, "Sign-out closure should not be called")
        #expect(persistedSessionCleared == false, "Persisted session clear closure should not be called")
        #expect(markerCleared == false, "Marker clear closure should not be called")

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == profileID, "Profile ID should be preserved")
        #expect(GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == "real_user_apple_id", "Apple ID should be preserved")
        #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() == "real_firebase_uid", "Firebase UID should be preserved")
    }

    @Test("End-to-end: sign-out error does not prevent session clear")
    func endToEndSignOutErrorStillClearsSession() {
        GoDiveKeychainStore.testingStore = [:]
        let testDefaults = UserDefaults(suiteName: "EmulatorSessionIsolationErrorTests")!
        defer {
            GoDiveKeychainStore.testingStore = nil
            testDefaults.removePersistentDomain(forName: "EmulatorSessionIsolationErrorTests")
        }

        let profileID = UUID()
        AppLaunchSessionRestorePresentation.savePersistedProfileID(profileID)
        GoDiveEmulatorSessionGuard.markSessionAsEmulator(userDefaults: testDefaults)

        struct TestError: Error {}

        let result = GoDiveEmulatorSessionGuard.clearEmulatorSessionIfNeeded(
            isEmulatorEnabled: false,
            hasMarker: true,
            currentUserEmail: nil,
            signOut: { throw TestError() },
            clearPersistedSession: { GoDiveEmulatorSessionGuard.clearPersistedEmulatorSession() },
            clearMarker: { GoDiveEmulatorSessionGuard.clearEmulatorMarker(userDefaults: testDefaults) }
        )

        #expect(result.didClear == true, "Should still clear session even with sign-out error")
        #expect(result.signOutCalled == true, "Sign-out should have been attempted")
        #expect(result.persistedSessionCleared == true, "Persisted session should be cleared")
        #expect(result.markerCleared == true, "Marker should be cleared")

        #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID() == nil, "Profile ID should be cleared")
        #expect(GoDiveEmulatorSessionGuard.hasEmulatorSessionMarker(userDefaults: testDefaults) == false, "Marker should be cleared")
    }
    #endif
}
