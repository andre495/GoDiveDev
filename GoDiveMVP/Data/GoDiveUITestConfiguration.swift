import Foundation

/// Launch flags for **`XCUIApplication.goDiveForUITesting()`** (see **`GoDiveMVPUITests`**).
enum GoDiveUITestConfiguration: Sendable {
    nonisolated static let launchArgument = "-GoDiveUITest"
    nonisolated static let launchEnvironmentKey = "GoDiveUITest"

    /// Readable from **`nonisolated`** presentation helpers and data-layer gates.
    nonisolated static var isActive: Bool {
        if ProcessInfo.processInfo.arguments.contains(launchArgument) {
            return true
        }
        return ProcessInfo.processInfo.environment[launchEnvironmentKey] == "1"
    }

    #if DEBUG
    /// DEBUG-only: Open Explore → Map → All Sites on launch with real catalog sites.
    /// Use with `-GoDiveMockSeed` to populate catalog data.
    /// Skips onboarding and the UITest stub to exercise the actual map view.
    nonisolated static let openExploreMapArgument = "-GoDiveOpenExploreMap"

    nonisolated static var shouldOpenExploreMap: Bool {
        ProcessInfo.processInfo.arguments.contains(openExploreMapArgument)
    }
    #endif
}
