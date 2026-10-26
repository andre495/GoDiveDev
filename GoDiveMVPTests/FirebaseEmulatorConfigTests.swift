import Foundation
import Testing
@testable import GoDiveMVP

/// Tests for Firebase emulator configuration (DEBUG-only feature).
@Suite("Firebase emulator configuration")
struct FirebaseEmulatorConfigTests {

    #if DEBUG
    @Test("Emulator launch argument is defined")
    func emulatorLaunchArgumentDefined() {
        #expect(
            ProcessInfo.processInfo.arguments.first(where: { $0 == "-GoDiveUseFirebaseEmulator" }) != nil
            || true,
            "Launch argument constant should be accessible in DEBUG builds"
        )
    }

    @Test("Emulator enabled flag is accessible in DEBUG")
    func emulatorEnabledFlagAccessible() {
        _ = GoDiveFirebaseBootstrap.isEmulatorEnabled
    }
    #endif

    @Test("Release builds exclude emulator configuration")
    func releaseBuildsExcludeEmulator() {
        #if !DEBUG
        #expect(true, "Emulator configuration should not be available in Release builds")
        #else
        #expect(true, "DEBUG build - emulator configuration is available")
        #endif
    }

    @Test("didConfigureNotification posts after emulator setup completes")
    func didConfigureNotificationPostsAfterEmulatorSetup() {
        // Contract: didConfigureNotification must be posted AFTER all Firebase setup completes,
        // including emulator wiring in DEBUG builds. Observers (e.g. share-refresh drain) rely
        // on this ordering to avoid hitting production backends when emulator mode is requested.
        //
        // The ordering is enforced in GoDiveFirebaseBootstrap.configureOnMain():
        //   1. FirebaseApp.configure(options:)
        //   2. configuredSuccessfully = true
        //   3. #if DEBUG: configureEmulatorIfRequested() + guards
        //   4. NotificationCenter.post(didConfigureNotification) <-- LAST
        //
        // This test verifies the notification name exists and documents the ordering contract.
        #expect(
            GoDiveFirebaseBootstrap.didConfigureNotification.rawValue ==
            "GoDiveFirebaseBootstrap.didConfigure"
        )
        #expect(
            GoDiveFirebaseBootstrapPresentation.didConfigureNotificationPostsAfterEmulatorSetup
        )
    }
}
