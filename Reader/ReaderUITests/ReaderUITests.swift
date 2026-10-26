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
        #if os(macOS)
        XCTAssertFalse(app.outlines["readerTimeline"].label.isEmpty)
        #endif
        connect.clickOrTap()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["username"].exists)
        XCTAssertTrue(app.secureTextFields["apiPassword"].exists)
        app.buttons["cancelConnection"].firstMatch.clickOrTap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }

    #if os(macOS)
    func testVoiceOverAnnouncesReaderAndMovesFocus() throws {
        let app = launchReader(arguments: ["--ui-testing-timeline", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["timelineFixturePhase"], equalTo: "ready", timeout: 10)
        let timeline = app.outlines["readerTimeline"]
        let first = timeline.staticTexts["Timeline article 299"].firstMatch
        XCTAssertTrue(first.wait(for: \.isHittable, toEqual: true, timeout: 5))
        let voiceOver = XCUIDevice.shared.voiceOverService
        let wasEnabled = voiceOver.isEnabled
        let initialState = XCTAttachment(string: "VoiceOver originally enabled: \(wasEnabled)")
        initialState.name = "Native VoiceOver initial state"
        initialState.lifetime = .keepAlways
        add(initialState)
        let initialContext = XCTAttachment(string: voiceOver.debugDescription)
        initialContext.name = "Native VoiceOver service before activation"
        initialContext.lifetime = .keepAlways
        add(initialContext)
        addTeardownBlock {
            try await MainActor.run {
                let service = XCUIDevice.shared.voiceOverService
                if service.isEnabled != wasEnabled {
                    if wasEnabled { try service.enable() } else { try service.disable() }
                }
                XCTContext.runActivity(named: "Restore native VoiceOver state") { activity in
                    let restored = XCTAttachment(string: "VoiceOver enabled after restoration: \(service.isEnabled)")
                    restored.name = "Native VoiceOver restored state"
                    restored.lifetime = .keepAlways
                    activity.add(restored)
                    let context = XCTAttachment(string: service.debugDescription)
                    context.name = "Native VoiceOver service after restoration"
                    context.lifetime = .keepAlways
                    activity.add(context)
                }
                XCTAssertEqual(service.isEnabled, wasEnabled)
            }
        }
        try voiceOver.enable()
        XCTAssertTrue(voiceOver.isEnabled)
        first.click()
        func captureSpeech(_ step: String, operation: () throws -> XCUIVoiceOverService.Output) throws -> String {
            try XCTContext.runActivity(named: "Native VoiceOver \(step)") { activity in
                let context = XCTAttachment(string: voiceOver.debugDescription)
                context.name = "Native VoiceOver service before \(step)"
                context.lifetime = .keepAlways
                activity.add(context)
                let utterance = try operation().utterance
                let attachment = XCTAttachment(string: utterance)
                attachment.name = "Actual native VoiceOver \(step)"
                attachment.lifetime = .keepAlways
                activity.add(attachment)
                XCTAssertFalse(utterance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                return utterance
            }
        }
        var speech = [
            try captureSpeech("current") { try voiceOver.currentSpeech() },
            try captureSpeech("enter timeline") { try voiceOver.moveIn() }
        ]
        let expectedTitles = ["Timeline article 299", "Timeline article 298"]
        var announcedTitles = Set(expectedTitles.filter { title in speech.contains { $0.contains(title) } })
        for step in 1...20 {
            if announcedTitles.count == expectedTitles.count { break }
            let utterance = try captureSpeech("forward \(step)") { try voiceOver.moveForward() }
            speech.append(utterance)
            announcedTitles.formUnion(expectedTitles.filter { utterance.contains($0) })
        }
        XCTAssertEqual(announcedTitles, Set(expectedTitles), "Actual VoiceOver must reach both adjacent article titles: \(speech)")
        XCTAssertGreaterThan(Set(speech).count, 1)
        let window = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        window.name = "Native Reader during actual VoiceOver focus navigation"
        window.lifetime = .keepAlways
        add(window)
    }

    func testLoadedTimelineScrollingMetrics() throws {
        let app = launchReader(arguments: ["--ui-testing-load", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["loadFixturePhase"], equalTo: "ready", timeout: 30)
        waitForValue(app.staticTexts["loadFixtureCounts"], equalTo: "10000 articles · 100 feeds · 10 folders")
        let timeline = app.outlines["readerTimeline"]
        let first = timeline.staticTexts["Load article 0"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.wait(for: \.isHittable, toEqual: true, timeout: 5))
        timeline.scroll(byDeltaX: 0, deltaY: -500)
        XCTAssertFalse(first.isHittable)
        timeline.scroll(byDeltaX: 0, deltaY: 500)
        XCTAssertTrue(first.wait(for: \.isHittable, toEqual: true, timeout: 5))

        let geometryBefore = "window=\(app.windows.firstMatch.frame); timeline=\(timeline.frame)"
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app),
                          XCTHitchMetric(application: app)], options: options) {
            timeline.scroll(byDeltaX: 0, deltaY: -500)
            timeline.scroll(byDeltaX: 0, deltaY: 500)
        }
        XCTAssertTrue(first.wait(for: \.isHittable, toEqual: true, timeout: 5))
        let geometry = XCTAttachment(string: "Before: \(geometryBefore)\nAfter: window=\(app.windows.firstMatch.frame); timeline=\(timeline.frame)\n10000 stored articles; normal initial 200-row page; five recorded down/up pairs; no calibrated baseline.")
        geometry.name = "Native loaded timeline measurement geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "Native loaded timeline after measured scrolling"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOPMLExportUsesNativeSavePanel() throws {
        let app = launchReader(arguments: ["--ui-testing-timeline", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["timelineFixturePhase"], equalTo: "ready", timeout: 10)
        app.descendants(matching: .any)["readerActions"].firstMatch.click()
        let export = app.menuItems["Export OPML"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.click()
        let panel = app.sheets["save-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReaderExport-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let name = panel.textFields["saveAsNameTextField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("ReaderExportProbe.opml")
        XCTAssertEqual(name.value as? String, "ReaderExportProbe.opml")
        app.typeKey("g", modifierFlags: [.command, .shift])
        let destination = panel.sheets["GoToWindow"]
        let path = destination.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.typeKey("a", modifierFlags: .command)
        path.typeText(directory.path)
        XCTAssertEqual(path.value as? String, directory.path)
        path.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        XCTAssertTrue(destination.wait(for: \.exists, toEqual: false, timeout: 5))
        waitForValue(panel.popUpButtons["where popup"], equalTo: directory.lastPathComponent)
        let save = panel.buttons["OKButton"]
        XCTAssertTrue(save.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        save.click()
        XCTAssertTrue(panel.wait(for: \.exists, toEqual: false, timeout: 5))
        let written = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                (try? FileManager.default.contentsOfDirectory(atPath: directory.path).count) == 1
            },
            object: nil
        )
        let result = XCTWaiter.wait(for: [written], timeout: 10)
        let outputs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let filenames = XCTAttachment(string: outputs.map(\.lastPathComponent).joined(separator: "\n"))
        filenames.name = "Native OPML export filenames"
        filenames.lifetime = .keepAlways
        add(filenames)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(outputs.count, 1)
        let output = try XCTUnwrap(outputs.first)
        let data = try Data(contentsOf: output)
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("<opml"))
        XCTAssertEqual(output.lastPathComponent, "ReaderExportProbe.opml")
    }

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
        let menuEvidence = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        menuEvidence.name = "Native feed confirmation while timeline query remains held"
        menuEvidence.lifetime = .keepAlways
        add(menuEvidence)
        app.windows.firstMatch.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(app.buttons["confirmFeedRead"].wait(for: \.exists, toEqual: false, timeout: 5))
        // Native modal dialogs can hide background diagnostics from the accessibility query.
        // Check the full menu/dialog/cancellation interval once its controls are accessible again.
        waitForValue(queries, equalTo: before)
        waitForValue(app.staticTexts["timelineFeedReadCalls"], equalTo: "0")
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
        waitForPositiveValue(app.staticTexts["imageLoadHeld"])

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

        waitForPositiveValue(app.staticTexts["imageLoadHeld"])
        let cancelledBeforeRemoval = try XCTUnwrap(Int(app.staticTexts["imageLoadCancelled"].value as? String ?? ""))
        app.buttons["removeImageLoadFeeds"].click()
        waitForValue(phase, equalTo: "removed")
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "feedRow-"))
        let noRows = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in rows.count == 0 }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [noRows], timeout: 5), .completed)
        waitForValueGreaterThan(app.staticTexts["imageLoadCancelled"], baseline: cancelledBeforeRemoval)
        waitForValue(app.staticTexts["imageLoadActive"], equalTo: "0")
        waitForValue(app.staticTexts["imageLoadHeld"], equalTo: "0")
        let maximumActive = try XCTUnwrap(Int(app.staticTexts["imageLoadMaximumActive"].value as? String ?? ""))
        XCTAssertLessThanOrEqual(maximumActive, 3)
        let cancelled = try XCTUnwrap(app.staticTexts["imageLoadCancelled"].value as? String)
        let counters = XCTAttachment(string: "cancelledBeforeRemoval=\(cancelledBeforeRemoval), cancelledAfterRemoval=\(cancelled), active=0, maximumActive=\(maximumActive)")
        counters.name = "Image load cancellation after native rows disappear"
        counters.lifetime = .keepAlways
        add(counters)
    }

    private func waitForValue(_ element: XCUIElement, equalTo expected: String, timeout: TimeInterval = 5,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected \(expected); observed \(element.exists ? String(describing: element.value) : "unavailable element")",
                       file: file, line: line)
    }

    private func waitForPositiveValue(_ element: XCUIElement, timeout: TimeInterval = 20) {
        waitForValueGreaterThan(element, baseline: 0, timeout: timeout)
    }

    private func waitForValueGreaterThan(_ element: XCUIElement, baseline: Int, timeout: TimeInterval = 5) {
        let predicate = NSPredicate { _, _ in (Int(element.value as? String ?? "") ?? -1) > baseline }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    func testArticleRemovalCancelsExtractionAndBlockedPageKeepsSavedContent() throws {
        let app = launchReader(arguments: ["--ui-testing-content", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        waitForValue(app.staticTexts["contentFixturePhase"], equalTo: "ready", timeout: 10)
        let timeline = app.outlines["readerTimeline"]
        let a = timeline.staticTexts["Saved article A"].firstMatch
        XCTAssertTrue(a.waitForExistence(timeout: 10))
        a.click()
        let savedA = app.webViews.firstMatch.staticTexts["Saved native article A"].firstMatch
        XCTAssertTrue(savedA.waitForExistence(timeout: 10))
        app.descendants(matching: .any)["articleActions"].firstMatch.click()
        app.menuItems["loadFullText"].firstMatch.click()
        waitForValue(app.staticTexts["contentActive"], equalTo: "1")
        waitForValue(app.staticTexts["contentRequests"], equalTo: "1")
        timeline.staticTexts["Saved article B"].firstMatch.click()
        waitForValue(app.staticTexts["articleDetailTitle"], equalTo: "Saved article B")
        waitForValue(app.staticTexts["contentCancelled"], equalTo: "1")
        waitForValue(app.staticTexts["contentActive"], equalTo: "0")
        let savedB = app.webViews.firstMatch.staticTexts["Saved native article B"].firstMatch
        XCTAssertTrue(savedB.waitForExistence(timeout: 10))
        XCTAssertTrue(savedB.wait(for: \.isHittable, toEqual: true, timeout: 5))
        app.descendants(matching: .any)["articleActions"].firstMatch.click()
        app.menuItems["loadFullText"].firstMatch.click()
        let ok = app.windows.firstMatch.buttons["OK"].firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: 10))
        ok.click()
        let warning = app.descendants(matching: .any)["fullTextUnavailable"].firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertTrue(savedB.isHittable)
        waitForValue(app.staticTexts["contentRequests"], equalTo: "2")
        waitForValue(app.staticTexts["contentActive"], equalTo: "0")
        waitForValue(app.staticTexts["contentCancelled"], equalTo: "1")
        let evidence = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        evidence.name = "Native Reader retains saved article with unavailable-full-text warning"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    func testWindowSearchAndSelectionSurviveClosingAnotherWindow() throws {
        let app = launchReader(arguments: ["--ui-testing-timeline", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        let firstID = app.windows.firstMatch.identifier
        XCTAssertFalse(firstID.isEmpty)
        let first = app.windows.matching(identifier: firstID).firstMatch
        waitForValue(first.staticTexts["timelineFixturePhase"], equalTo: "ready", timeout: 10)
        let firstRow = first.outlines["readerTimeline"].staticTexts["Timeline article 299"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.click()
        waitForValue(first.staticTexts["articleDetailTitle"], equalTo: "Timeline article 299")

        app.typeKey("n", modifierFlags: .command)
        let second = app.windows.matching(NSPredicate(format: "identifier != %@", firstID)).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 2)
        let secondSearch = second.searchFields.firstMatch
        XCTAssertTrue(secondSearch.waitForExistence(timeout: 5))
        secondSearch.click()
        secondSearch.typeText("article 298")
        waitForValue(second.staticTexts["timelineCounts"], equalTo: "Entries: 1 · Loaded originals: 1")
        second.outlines["readerTimeline"].staticTexts["Timeline article 298"].firstMatch.click()
        waitForValue(second.staticTexts["articleDetailTitle"], equalTo: "Timeline article 298")
        XCTAssertEqual(first.searchFields.firstMatch.value as? String, "")
        waitForValue(first.staticTexts["articleDetailTitle"], equalTo: "Timeline article 299")

        app.typeKey("`", modifierFlags: .command)
        let firstSearch = first.searchFields.firstMatch
        XCTAssertTrue(firstSearch.wait(for: \.isHittable, toEqual: true, timeout: 5))
        firstSearch.click()
        firstSearch.typeText("article 299")
        waitForValue(first.staticTexts["timelineCounts"], equalTo: "Entries: 1 · Loaded originals: 1")
        // Changing this window’s query intentionally clears only its own selection.
        first.outlines["readerTimeline"].staticTexts["Timeline article 299"].firstMatch.click()
        waitForValue(first.staticTexts["articleDetailTitle"], equalTo: "Timeline article 299")
        XCTAssertEqual(secondSearch.value as? String, "article 298")
        waitForValue(second.staticTexts["articleDetailTitle"], equalTo: "Timeline article 298")

        app.typeKey("`", modifierFlags: .command)
        let hold = second.buttons["holdTimelineQueries"]
        XCTAssertTrue(hold.wait(for: \.isHittable, toEqual: true, timeout: 5))
        hold.click()
        secondSearch.click()
        secondSearch.typeKey("a", modifierFlags: .command)
        secondSearch.typeText("article 270")
        waitForPositiveValue(second.staticTexts["timelineHeldQueries"])
        app.typeKey("`", modifierFlags: .command)
        let close = first.buttons[XCUIIdentifierCloseWindow]
        XCTAssertTrue(close.wait(for: \.isHittable, toEqual: true, timeout: 5))
        close.click()
        XCTAssertTrue(first.wait(for: \.exists, toEqual: false, timeout: 5))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertEqual(secondSearch.value as? String, "article 270")
        waitForPositiveValue(second.staticTexts["timelineHeldQueries"])
        second.buttons["releaseTimelineQueries"].click()
        waitForValue(second.staticTexts["timelineHeldQueries"], equalTo: "0")
        waitForValue(second.staticTexts["timelineCounts"], equalTo: "Entries: 1 · Loaded originals: 1")
        let survivorRow = second.outlines["readerTimeline"].staticTexts["Timeline article 270"].firstMatch
        XCTAssertTrue(survivorRow.waitForExistence(timeout: 5))
        survivorRow.click()
        waitForValue(second.staticTexts["articleDetailTitle"], equalTo: "Timeline article 270")
        let initialFrame = second.frame
        let narrowFrame = resizeWindow(second, delta: CGVector(dx: -240, dy: -160))
        XCTAssertTrue(secondSearch.isHittable)
        XCTAssertEqual(secondSearch.value as? String, "article 270")
        waitForValue(second.staticTexts["articleDetailTitle"], equalTo: "Timeline article 270")
        second.descendants(matching: .any)["readerActions"].firstMatch.click()
        app.menuItems["connectAccount"].click()
        let username = second.sheets.firstMatch.textFields["username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.click()
        username.typeText("Narrow window")
        XCTAssertEqual(username.value as? String, "Narrow window")
        second.sheets.firstMatch.buttons["cancelConnection"].firstMatch.click()
        let narrowEvidence = XCTAttachment(screenshot: second.screenshot())
        narrowEvidence.name = "Native Reader search, detail and account sheet remain usable after window resize"
        narrowEvidence.lifetime = .keepAlways
        add(narrowEvidence)
        let restoredFrame = resizeWindow(second, delta: CGVector(dx: 240, dy: 160))
        waitForValue(second.staticTexts["articleDetailTitle"], equalTo: "Timeline article 270")
        XCTAssertEqual(secondSearch.value as? String, "article 270")
        let dimensions = XCTAttachment(string: "initial=\(initialFrame), narrow=\(narrowFrame), restored=\(restoredFrame); independent searches/selections and native close completed; surviving search returned article 270.")
        dimensions.name = "Observed native window sizes and surviving search"
        dimensions.lifetime = .keepAlways
        add(dimensions)
        let evidence = XCTAttachment(screenshot: second.screenshot())
        evidence.name = "Surviving native window completes its held search after another window closes"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private func resizeWindow(_ window: XCUIElement, delta: CGVector) -> CGRect {
        let initialFrame = window.frame
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(delta))
        let resized = NSPredicate { _, _ in
            let frame = window.frame
            let widthChanged = delta.dx < 0 ? frame.width < initialFrame.width - 100 : frame.width > initialFrame.width + 100
            let heightChanged = delta.dy < 0 ? frame.height < initialFrame.height - 80 : frame.height > initialFrame.height + 80
            return widthChanged && heightChanged
        }
        let expectation = XCTNSPredicateExpectation(predicate: resized, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        return window.frame
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
