import XCTest

@MainActor
final class ReaderSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testConnectionFormCanBeOpenedAndCancelled() throws {
        let app = launchReader()
        let connect = app.buttons["connectFreshRSS"]
        XCTAssertTrue(connect.waitForExistence(timeout: 15))
        XCTAssertTrue(connect.wait(for: \.isHittable, toEqual: true, timeout: 5))
        connect.clickOrTap()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["username"].exists)
        XCTAssertTrue(app.secureTextFields["apiPassword"].exists)
        XCTAssertFalse(app.buttons["submitConnection"].isEnabled)
        app.buttons["cancelConnection"].firstMatch.clickOrTap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }

    #if os(macOS)
    func testNewWindowHasIndependentConnectionForm() throws {
        let app = launchReader()
        let firstID = app.windows.firstMatch.identifier
        XCTAssertFalse(firstID.isEmpty)
        let first = app.windows.matching(identifier: firstID).firstMatch

        app.typeKey("n", modifierFlags: .command)
        let second = app.windows.matching(NSPredicate(format: "identifier != %@", firstID)).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 2)

        second.buttons["connectFreshRSS"].click()
        let secondSheet = second.sheets.firstMatch
        let secondUsername = secondSheet.textFields["username"]
        XCTAssertTrue(secondUsername.waitForExistence(timeout: 5))
        secondUsername.click()
        secondUsername.typeText("Window B")

        // Window cycling works even when a small display leaves both windows fully overlapping.
        app.typeKey("`", modifierFlags: .command)
        let firstConnect = first.buttons["connectFreshRSS"]
        XCTAssertTrue(firstConnect.wait(for: \.isHittable, toEqual: true, timeout: 5))
        firstConnect.click()
        let firstSheet = first.sheets.firstMatch
        XCTAssertTrue(firstSheet.textFields["username"].waitForExistence(timeout: 5))
        XCTAssertEqual(firstSheet.textFields["username"].value as? String, "")
        XCTAssertEqual(secondUsername.value as? String, "Window B")

        firstSheet.buttons["cancelConnection"].firstMatch.click()
        XCTAssertTrue(first.buttons["connectFreshRSS"].waitForExistence(timeout: 5))
        XCTAssertTrue(secondSheet.exists)
        XCTAssertEqual(secondUsername.value as? String, "Window B")
        secondSheet.buttons["cancelConnection"].firstMatch.click()
        XCTAssertTrue(second.buttons["connectFreshRSS"].waitForExistence(timeout: 5))
    }
    #endif

    private func launchReader() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        #if os(macOS)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "The first window must open on launch without a keyboard command.")
        XCTAssertEqual(app.windows.count, 1)
        let attachment = XCTAttachment(string: "readyWindowCount=\(app.windows.count)")
        attachment.name = "XCUITest window setup"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
        return app
    }
}

private extension XCUIElement {
    func clickOrTap() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
