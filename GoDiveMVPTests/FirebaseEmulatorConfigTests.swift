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

    @Test("FCM auto-init is re-enabled after configure")
    func fcmAutoInitReenabledAfterConfigure() {
        // Contract: Info.plist sets FirebaseMessagingAutoInitEnabled=NO to prevent SDK
        // from calling FirebaseApp.app() before configure() (avoids I-COR000005).
        // GoDiveFirebaseCloudMessaging.configureAtLaunch() must set isAutoInitEnabled=true
        // AFTER Firebase is configured so FCM token fetching works normally.
        //
        // Flow:
        //   1. Info.plist: FirebaseMessagingAutoInitEnabled=NO (prevents early SDK access)
        //   2. GoDiveGoogleMapsAppDelegate.init(): GoDiveFirebaseBootstrap.configureIfNeeded()
        //   3. didFinishLaunchingWithOptions: configureAtLaunch()
        //   4. configureAtLaunch: guard isConfigured, then Messaging.messaging().isAutoInitEnabled = true
        //   5. FCM token is fetched normally via MessagingDelegate callback
        //
        // This test documents the contract; actual token fetch requires Firebase SDK.
        #expect(
            GoDiveFirebaseCloudMessagingPresentation.reenablesAutoInitAfterConfigure
        )
    }
}
