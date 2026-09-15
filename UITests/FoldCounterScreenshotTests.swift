import XCTest

/// Captures the actual interface using isolated, explicitly manual test entries.
/// These screenshots are review material, not proof of Duo hardware support.
final class FoldCounterScreenshotTests: XCTestCase {
    @MainActor func testCaptureListingScreensAndBundledHelp() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.staticTexts["todayCount"].waitForExistence(timeout: 10))
        for _ in 0..<3 {
            app.buttons["addManual"].tap()
            app.buttons["confirmManual"].firstMatch.tap()
        }
        XCTAssertEqual(app.staticTexts["todayCount"].value as? String, "3")
        capture(app, "01-today-manual-entries")
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Daily breakdown")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "02-history")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["privacyPolicy"].waitForExistence(timeout: 5))
        capture(app, "03-settings")
        app.buttons["privacyPolicy"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Your counter stays on your device")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "04-privacy")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["helpSupport"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Why does the count miss openings?")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "05-support")
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
