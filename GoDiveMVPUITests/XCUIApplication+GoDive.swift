import XCTest

extension XCUIApplication {
    /// Must match **`GoDiveUITestConfiguration`** in the app target (fast launch + AX bootstrap).
    static func goDiveForUITesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-GoDiveUITest",
            "-UIViewAnimationEnabled",
            "NO",
        ]
        app.launchEnvironment["GoDiveUITest"] = "1"
        return app
    }
}
