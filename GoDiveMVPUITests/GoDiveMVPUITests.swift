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

    /// Regression: the country picker was attached inside `Form` section content, so
    /// presenting it recycled the anchor and dismissed the picker *and* the add-site sheet.
    /// Uses the UITest Explore harness (same host-root picker presentation as production sheets).
    @MainActor
    func testDiveSiteCountryPicker_staysPresentedOverAddSiteSheet() throws {
        XCTAssertTrue(
            app.otherElements["GoDive.UITest.Root"].waitForExistence(timeout: 20),
            "UI-test root should be visible"
        )

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 10), "Explore tab should appear")
        exploreTab.tap()

        let addButton = app.buttons["Explore.AddDiveSite"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Add dive site button should appear")
        addButton.tap()

        let addSheetRoot = app.otherElements["Explore.AddDiveSiteSheet.Root"]
        XCTAssertTrue(addSheetRoot.waitForExistence(timeout: 10), "Add dive site sheet should appear")

        let countryField = app.buttons["Open country picker"]
        XCTAssertTrue(countryField.waitForExistence(timeout: 10), "Country field should appear")
        countryField.tap()

        let pickerDone = app.buttons["DiveSiteForm.CountryPicker.Done"]
        let pickerRoot = app.descendants(matching: .any)["DiveSiteForm.CountryPicker.Root"]
        let pickerSearch = app.descendants(matching: .any)["DiveSiteForm.CountryPicker.SearchField"]
        let pickerVisible = pickerDone.waitForExistence(timeout: 10)
            || pickerRoot.waitForExistence(timeout: 2)
            || pickerSearch.waitForExistence(timeout: 2)
        XCTAssertTrue(pickerVisible, "Country picker should appear")

        XCTAssertTrue(
            addSheetRoot.exists,
            "Opening the country picker must keep the add-site sheet presented"
        )

        let dismissProbe = pickerDone.exists ? pickerDone : (pickerRoot.exists ? pickerRoot : pickerSearch)
        let pickerDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: dismissProbe
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [pickerDismissed], timeout: 3),
            .timedOut,
            "Country picker must stay presented instead of dismissing with the add-site sheet"
        )

        XCTAssertTrue(pickerDone.waitForExistence(timeout: 5), "Country picker Done should appear")
        pickerDone.tap()

        XCTAssertTrue(
            addSheetRoot.waitForExistence(timeout: 10),
            "Dismissing the country picker must return to the add-site sheet, not close it"
        )
    }
}
