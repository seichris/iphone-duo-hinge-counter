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
        app.swipeUp()
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
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Daily breakdown")).firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Automatic foreground tracking"].waitForExistence(timeout: 5))
    }
}
