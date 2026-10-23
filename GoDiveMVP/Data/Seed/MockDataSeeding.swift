import Foundation

/// Controls bundled JSON fixture loading at launch (**`MockDataSeeder`**).
///
/// Mock data seeding is gated by the **`-GoDiveMockSeed`** launch argument in Debug builds only.
/// Release builds compile-time disable seeding entirely — the sample JSON files are excluded from
/// the Release bundle via **`EXCLUDED_SOURCE_FILE_NAMES`**.
enum MockDataSeeding: Sendable {
    #if DEBUG
    nonisolated static let launchArgument = "-GoDiveMockSeed"

    /// Returns **`true`** only in Debug when the **`-GoDiveMockSeed`** launch argument is present.
    nonisolated static var isLaunchSeedingEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
    #else
    /// Compile-time **`false`** in Release — seeder code path is never invoked.
    nonisolated static let isLaunchSeedingEnabled = false
    #endif
}
