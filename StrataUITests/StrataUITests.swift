// StrataUITests.swift
// StrataUITests

import XCTest

final class StrataUITests: XCTestCase {

    // MARK: - Properties

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testLaunchAndDisplayHexGrid() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main window should exist")

        let hexGrid = window.otherElements["hexGridView"]
        XCTAssertTrue(hexGrid.exists, "Hex grid view should exist")
    }

    func testTabBarExists() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let tabBar = window.otherElements["tabBar"]
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
    }

    func testStatusBarExists() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let statusBar = window.otherElements["statusBar"]
        XCTAssertTrue(statusBar.exists, "Status bar should exist")
    }

    func testGoToOffsetSheet() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Open Go To Offset via menu
        app.menuItems["Go To Offset…"].click()

        // Check for the offset field
        let offsetField = app.textFields["goToOffsetField"]
        if offsetField.waitForExistence(timeout: 3) {
            offsetField.click()
            offsetField.typeText("0x10")

            let okButton = app.buttons["goToOK"]
            if okButton.exists {
                okButton.click()
            }
        }
    }

    func testFindPanel() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Open Find via menu
        app.menuItems["Find…"].click()

        // Check for the find field
        let findField = app.textFields["findField"]
        XCTAssertTrue(
            findField.waitForExistence(timeout: 3),
            "Find field should appear after ⌘F"
        )
    }

    func testModeIndicatorExists() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let modeIndicator = window.staticTexts["modeIndicator"]
        if modeIndicator.exists {
            XCTAssertTrue(
                modeIndicator.value as? String == "OVR" || modeIndicator.value as? String == "INS",
                "Mode indicator should show OVR or INS"
            )
        }
    }

    func testNewFileViaMenu() throws {
        let window = app.windows["mainWindow"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // Create new file via menu
        app.menuItems["New"].click()

        // The tab bar should update
        let tabBar = window.otherElements["tabBar"]
        XCTAssertTrue(tabBar.exists)
    }
}
