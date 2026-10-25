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
    func testImageLoadKeepsConnectionFormResponsiveAndCancelsRemovedRows() throws {
        let app = launchReader(arguments: ["--ui-testing-image-load"])
        let phase = app.staticTexts["imageLoadPhase"]
        waitForValue(phase, equalTo: "ready", timeout: 10)
        XCTAssertTrue(app.buttons["Load feed 0"].waitForExistence(timeout: 5))
        app.buttons["startImageLoad"].click()
        waitForPositiveValue(app.staticTexts["imageLoadDelivered"])
        waitForPositiveValue(app.staticTexts["imageLoadRetries"])
        waitForPositiveValue(app.staticTexts["imageLoadActive"])

        app.descendants(matching: .any)["readerSidebar"].firstMatch.scroll(byDeltaX: 0, deltaY: -300)
        app.descendants(matching: .any)["readerActions"].firstMatch.click()
        app.menuItems["connectAccount"].click()
        let username = app.textFields["username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.click()
        username.typeText("Responsive during image load")
        XCTAssertEqual(username.value as? String, "Responsive during image load")
        app.buttons["cancelConnection"].firstMatch.click()
        waitForPositiveValue(app.staticTexts["imageLoadActive"])
        let imageLoad = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        imageLoad.name = "Native Reader during image retries and thumbnail loading"
        imageLoad.lifetime = .keepAlways
        add(imageLoad)

        waitForPositiveValue(app.staticTexts["imageLoadActive"])
        let cancelledBeforeRemoval = try XCTUnwrap(Int(app.staticTexts["imageLoadCancelled"].value as? String ?? ""))
        app.buttons["removeImageLoadFeeds"].click()
        waitForValue(phase, equalTo: "removed")
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "feedRow-"))
        let noRows = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in rows.count == 0 }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [noRows], timeout: 5), .completed)
        waitForValueGreaterThan(app.staticTexts["imageLoadCancelled"], baseline: cancelledBeforeRemoval)
        waitForValue(app.staticTexts["imageLoadActive"], equalTo: "0")
        let maximumActive = try XCTUnwrap(Int(app.staticTexts["imageLoadMaximumActive"].value as? String ?? ""))
        XCTAssertLessThanOrEqual(maximumActive, 3)
        let cancelled = try XCTUnwrap(app.staticTexts["imageLoadCancelled"].value as? String)
        let counters = XCTAttachment(string: "cancelledBeforeRemoval=\(cancelledBeforeRemoval), cancelledAfterRemoval=\(cancelled), active=0, maximumActive=\(maximumActive)")
        counters.name = "Image load cancellation after native rows disappear"
        counters.lifetime = .keepAlways
        add(counters)
    }

    private func waitForValue(_ element: XCUIElement, equalTo expected: String, timeout: TimeInterval = 5) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitForPositiveValue(_ element: XCUIElement, timeout: TimeInterval = 20) {
        waitForValueGreaterThan(element, baseline: 0, timeout: timeout)
    }

    private func waitForValueGreaterThan(_ element: XCUIElement, baseline: Int, timeout: TimeInterval = 5) {
        let predicate = NSPredicate { _, _ in (Int(element.value as? String ?? "") ?? -1) > baseline }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

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

    private func launchReader(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
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
