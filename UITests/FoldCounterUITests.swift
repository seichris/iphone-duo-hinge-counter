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
