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
        app.buttons["cancelConnection"].firstMatch.clickOrTap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }

    #if os(macOS)
    func testDelayedTimelineQueryKeepsInputAndFeedMenuResponsive() throws {
        let app = launchReader(arguments: ["--ui-testing-timeline", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["timelineFixturePhase"], equalTo: "ready", timeout: 10)
        let first = app.outlines["readerTimeline"].staticTexts["Timeline article 299"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.click()
        app.buttons["holdTimelineQueries"].click()
        app.outlines["readerSidebar"].buttons["Timeline fixture"].click()
        waitForPositiveValue(app.staticTexts["timelineHeldQueries"])
        let search = app.searchFields.firstMatch
        search.click()
        search.typeText("Representative")
        waitForPositiveValue(app.staticTexts["timelineHeldQueries"])
        app.descendants(matching: .any)["readerActions"].firstMatch.click()
        app.menuItems["connectAccount"].click()
        let username = app.textFields["username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.click()
        username.typeText("Input while timeline query waits")
        XCTAssertEqual(username.value as? String, "Input while timeline query waits")
        waitForPositiveValue(app.staticTexts["timelineHeldQueries"])
        app.buttons["cancelConnection"].firstMatch.click()
        let timeline = app.outlines["readerTimeline"]
        timeline.scroll(byDeltaX: 0, deltaY: -250)
        timeline.scroll(byDeltaX: 0, deltaY: 250)
        XCTAssertTrue(first.wait(for: \.isHittable, toEqual: true, timeout: 5))
        let queries = app.staticTexts["timelineQueryCount"]
        let before = try XCTUnwrap(queries.value as? String)
        first.rightClick()
        let markFeed = app.menuItems["Mark all in feed read…"]
        XCTAssertTrue(markFeed.waitForExistence(timeout: 5))
        waitForValue(queries, equalTo: before)
        markFeed.click()
        XCTAssertTrue(app.buttons["confirmFeedRead"].waitForExistence(timeout: 5))
        waitForValue(queries, equalTo: before)
        waitForValue(app.staticTexts["timelineFeedReadCalls"], equalTo: "0")
        let menuEvidence = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        menuEvidence.name = "Native feed confirmation while timeline query remains held"
        menuEvidence.lifetime = .keepAlways
        add(menuEvidence)
        app.windows.firstMatch.buttons["Cancel"].firstMatch.click()
        waitForValue(queries, equalTo: before)
        waitForValue(app.staticTexts["timelinePendingReadCount"], equalTo: "0")
        first.rightClick()
        markFeed.click()
        app.buttons["confirmFeedRead"].click()
        waitForValue(app.staticTexts["timelineFeedReadCalls"], equalTo: "1")
        waitForValue(app.staticTexts["timelinePendingReadCount"], equalTo: "300")
        waitForPositiveValue(app.staticTexts["timelineHeldQueries"])
        let evidence = XCTAttachment(string: "Native form input and scrolling completed while a timeline query was held; menu and cancelled confirmation left lookup count=\(before), feedReadCalls=0, pending=0. Confirmation called feed read once and queued all 300 unread rows beyond the 200-row page.")
        evidence.name = "Delayed native query and confirmed feed action"
        evidence.lifetime = .keepAlways
        add(evidence)
        app.buttons["releaseTimelineQueries"].click()
        waitForValue(app.staticTexts["timelineHeldQueries"], equalTo: "0")
        app.outlines["readerSidebar"].buttons["Unread"].click()
        waitForValue(app.staticTexts["timelineCounts"], equalTo: "Entries: 0 · Loaded originals: 0")
        XCTAssertFalse(app.staticTexts["Timeline article 299"].exists)
        let filtered = XCTAttachment(string: "After all 300 read commits, the native Unread filter shows Entries: 0 · Loaded originals: 0 and clears the previous article detail.")
        filtered.name = "Native unread counts after confirmed feed read"
        filtered.lifetime = .keepAlways
        add(filtered)
    }

    func testTimelineSupportsKeyboardSelectionAndBulkRead() throws {
        let app = launchReader(arguments: ["--ui-testing-timeline", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["timelineFixturePhase"], equalTo: "ready", timeout: 10)
        let first = app.outlines["readerTimeline"].staticTexts["Timeline article 299"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.click()
        app.typeKey(.downArrow, modifierFlags: .shift)
        let summary = app.descendants(matching: .any)["selectionSummary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        waitForValue(summary, equalTo: "Selected entries: 2")
        let pending = app.staticTexts["timelinePendingReadCount"]
        waitForValue(pending, equalTo: "0")
        first.rightClick()
        let markRead = app.menuItems["Mark read"]
        XCTAssertTrue(markRead.waitForExistence(timeout: 5))
        XCTAssertTrue(markRead.isEnabled)
        let menu = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        menu.name = "Native Mac keyboard multiselection and context menu"
        menu.lifetime = .keepAlways
        add(menu)
        markRead.click()
        waitForValue(pending, equalTo: "2")
        XCTAssertTrue(summary.exists)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(summary.wait(for: \.exists, toEqual: false, timeout: 5))
        let evidence = XCTAttachment(string: "Shift-Down selected two rows; context-menu Mark read queued exactly two read changes; Down restored single selection.")
        evidence.name = "Native timeline selection and persistent outbox observation"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

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
