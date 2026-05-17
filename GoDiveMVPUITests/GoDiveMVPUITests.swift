//
//  GoDiveMVPUITests.swift
//  GoDiveMVPUITests
//

import XCTest

final class GoDiveMVPUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Avoid Xcode’s per–UI-configuration launch loop (can flake with **“Failed to terminate”** on Simulator).
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.goDiveForUITesting()
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    @MainActor
    func testLaunch() throws {
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 45),
            "App should reach runningForeground"
        )

        XCTAssertTrue(
            app.otherElements["GoDive.UITest.Root"].waitForExistence(timeout: 20),
            "UI-test root should be visible"
        )

        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 10),
            "Home tab should appear"
        )

        XCTAssertTrue(
            app.buttons["Profile"].waitForExistence(timeout: 10),
            "Profile control should be visible on Home"
        )
    }
}
