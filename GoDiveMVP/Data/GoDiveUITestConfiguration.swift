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
}
