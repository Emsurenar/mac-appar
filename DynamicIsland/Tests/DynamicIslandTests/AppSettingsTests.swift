import XCTest
@testable import DynamicIsland

final class AppSettingsTests: XCTestCase {
    /// A fresh, empty settings suite, so the tests never touch the real settings.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "DynamicIslandTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        body(defaults)
        defaults.removePersistentDomain(forName: name)
    }

    @MainActor func testDefaultsForANewUser() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            XCTAssertTrue(settings.hoverToOpen)
            XCTAssertTrue(settings.showLiveActivity)
            XCTAssertFalse(settings.replaceSystemHUD, "needs Accessibility, so it starts off")
            XCTAssertEqual(settings.homeFolderName, "Home")
            XCTAssertTrue(settings.hiddenCalendarIDs.isEmpty)
            XCTAssertTrue(settings.showWaterReminders)
            XCTAssertEqual(settings.waterIntervalMinutes, 45)
            XCTAssertEqual(settings.waterDailyGoal, 8)
            XCTAssertTrue(settings.showClipboardTab)
            XCTAssertTrue(settings.pasteFromClipboardHistory)
            XCTAssertTrue(settings.showScreenshots)
            XCTAssertTrue(settings.showSystemTab)
            XCTAssertTrue(settings.showShelfTab)
        }
    }

    @MainActor func testChangesAreSavedAndReadBack() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.hoverToOpen = false
            settings.homeFolderName = "Hem"
            settings.hiddenCalendarIDs = ["work"]

            let reloaded = AppSettings(defaults: defaults)
            XCTAssertFalse(reloaded.hoverToOpen)
            XCTAssertEqual(reloaded.homeFolderName, "Hem")
            XCTAssertEqual(reloaded.hiddenCalendarIDs, ["work"])
        }
    }
}
