import Foundation

/// Launch flags for **`XCUIApplication.goDiveForUITesting()`** (see **`GoDiveMVPUITests`**).
enum GoDiveUITestConfiguration {
    static let launchArgument = "-GoDiveUITest"
    static let launchEnvironmentKey = "GoDiveUITest"

    static var isActive: Bool {
        if ProcessInfo.processInfo.arguments.contains(launchArgument) {
            return true
        }
        return ProcessInfo.processInfo.environment[launchEnvironmentKey] == "1"
    }
}
