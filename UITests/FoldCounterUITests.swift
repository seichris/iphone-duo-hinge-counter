import XCTest

final class FoldCounterUITests: XCTestCase {
    @MainActor func testManualCountPersistsAndDemoIsIsolated() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        let count = app.staticTexts["todayCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.value as? String, "0")
        app.buttons["addManual"].tap()
        app.buttons["confirmManual"].firstMatch.tap()
        XCTAssertEqual(count.value as? String, "1")
        revealButton(app.buttons["openDemo"], in: app)
        app.buttons["openDemo"].tap()
        app.buttons["simulateFold"].tap()
        app.buttons["simulateFold"].tap()
        XCTAssertEqual(app.staticTexts["demoCount"].label, "2")
        app.buttons["closeDemo"].tap()
        XCTAssertEqual(count.value as? String, "1")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.value as? String, "1")
    }

    @MainActor func testHistoryAndSettingsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        openTab("History", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Daily breakdown")).firstMatch.waitForExistence(timeout: 5))
        openTab("Settings", in: app)
        XCTAssertTrue(app.switches["Automatic foreground tracking"].waitForExistence(timeout: 5))
    }

    @MainActor func testCoverageAndDemoRemainReachableAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["todayCount"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "0")
        let header = XCTAttachment(screenshot: app.screenshot())
        header.name = "Largest accessibility dashboard header"
        header.lifetime = .keepAlways
        add(header)
        XCTAssertTrue(app.staticTexts["trackingDisclosure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["trackingDisclosure"].label.contains("not recovered"))
        revealButton(app.buttons["openDemo"], in: app)
        app.buttons["openDemo"].tap()
        XCTAssertTrue(app.buttons["simulateFold"].waitForExistence(timeout: 5))
        app.buttons["closeDemo"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessibility dashboard coverage"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testDocumentAndEraseCancellationPreservesHistory() {
        continueAfterFailure = false
        executionTimeAllowance = 600
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.staticTexts["todayCount"].waitForExistence(timeout: 10))
        app.buttons["addManual"].tap()
        app.buttons["confirmManual"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "1")
        openTab("Settings", in: app)
        for title in ["Export daily history (CSV)", "Export backup (JSON)", "Restore a JSON backup"] {
            let button = app.buttons[title]
            for _ in 0..<5 where !button.exists { app.swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            let cancel = app.buttons["Cancel"].firstMatch
            // Files can reopen inside On My iPhone instead of its root browser.
            // The Cancel control is on the root browser, behind its Back button.
            if !cancel.waitForExistence(timeout: 5), app.buttons["Save"].exists {
                let back = app.navigationBars.buttons.firstMatch
                if back.exists { back.tap() }
            }
            XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Document picker must allow cancellation")
            cancel.tap()
            XCTAssertFalse(app.alerts["Could not complete the action"].waitForExistence(timeout: 2),
                           "Cancelling a document action is not a failure")
        }
        app.buttons["Erase all counts"].tap()
        XCTAssertTrue(app.staticTexts["Erase all saved counts?"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.tap()
        openTab("Today", in: app)
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "1")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["todayCount"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "1")
    }

    #if DUO_HINGE_API
    @MainActor func testHingeSubscriptionRefreshesAfterPauseAndResume() throws {
        continueAfterFailure = false
        guard #available(iOS 27.1, *) else { throw XCTSkip("Hinge API requires iOS 27.1") }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.staticTexts["todayCount"].waitForExistence(timeout: 10))
        openTab("Settings", in: app)
        // SwiftUI exposes the labeled row and the thumb as nested switches.
        let toggle = app.switches["Automatic foreground tracking"].switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let status = app.staticTexts["trackingStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let resolved = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Observing while active", "No hinge on this device")
        for _ in 0..<2 {
            // Use the actual status value, not a hidden tab or a combined row label.
            expectation(for: resolved, evaluatedWith: status)
            waitForExpectations(timeout: 10)
            toggle.tap()
            expectation(for: NSPredicate(format: "label CONTAINS %@", "Tracking paused"), evaluatedWith: status)
            waitForExpectations(timeout: 5)
            toggle.tap()
        }
        expectation(for: resolved, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        openTab("Today", in: app)
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "0", "An initial open pose is not a recorded opening")
    }
    #endif

    @MainActor private func openTab(_ label: String, in app: XCUIApplication) {
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return
        }
        let adaptiveButton = app.buttons[label]
        XCTAssertTrue(adaptiveButton.waitForExistence(timeout: 5), "Required navigation item must remain reachable")
        adaptiveButton.tap()
    }

    @MainActor private func revealButton(_ element: XCUIElement, in app: XCUIApplication) {
        // XCTest scrolls a containing ScrollView while tapping an existing button.
        // `isHittable` is false for some SwiftUI controls in ArrangementView even
        // though the same semantic tap succeeds, so existence is the stable gate.
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Required dashboard action must remain reachable")
    }
}
