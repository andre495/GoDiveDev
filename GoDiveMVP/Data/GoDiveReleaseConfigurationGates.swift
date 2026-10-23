import Foundation

/// Compile-time / unit-testable Release gates (OWASP policy §5 R1–R2 / R7).
///
/// Runtime UITest activation remains **`GoDiveUITestConfiguration.isActive`** (launch flag only).
enum GoDiveReleaseConfigurationGates: Sendable {

    /// **R1** — mock launch seeding must stay off for ship (Release) or off by default (Debug).
    ///
    /// In Release, **`MockDataSeeding.isLaunchSeedingEnabled`** is compile-time **`false`**.
    /// In Debug, it checks for **`-GoDiveMockSeed`** launch argument (default off).
    nonisolated static var isLaunchSeedingDisabled: Bool {
        !MockDataSeeding.isLaunchSeedingEnabled
    }

    #if DEBUG
    /// **R1** — whether mock seeding would activate for the given arguments (Debug-only, testable).
    nonisolated static func mockSeedingWouldBeActive(arguments: [String]) -> Bool {
        arguments.contains(MockDataSeeding.launchArgument)
    }
    #endif

    /// **R7** — crash CloudKit share reads as off when the key is unset (UserDefaults bool default).
    nonisolated static func isCrashShareDefaultOff(userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: AppUserSettings.shareCrashReportsKey) == nil
            && !AppUserSettings.shareCrashReports(userDefaults: userDefaults)
    }

    /// Parallel to **R7** for diagnostic-event developer share.
    nonisolated static func isSecurityEventShareDefaultOff(userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: AppUserSettings.shareSecurityEventsKey) == nil
            && !AppUserSettings.shareSecurityEvents(userDefaults: userDefaults)
    }

    /// **R2** — whether UITest root would activate for the given process launch inputs.
    nonisolated static func uiTestWouldBeActive(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if arguments.contains(GoDiveUITestConfiguration.launchArgument) {
            return true
        }
        return environment[GoDiveUITestConfiguration.launchEnvironmentKey] == "1"
    }

    /// Critical static gates that must pass before Archive / TestFlight.
    nonisolated static var criticalStaticGatesPass: Bool {
        isLaunchSeedingDisabled
    }
}
