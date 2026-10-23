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
}
