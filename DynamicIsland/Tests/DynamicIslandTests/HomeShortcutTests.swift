import XCTest
@testable import DynamicIsland

final class HomeShortcutTests: XCTestCase {
    func testLeadingEmojiBecomesTheIcon() {
        let shortcut = HomeShortcut(id: "1", name: "💡 Living Room")
        XCTAssertEqual(shortcut.emoji, "💡")
        XCTAssertEqual(shortcut.title, "Living Room")
    }

    func testPlainNameKeepsItsTitle() {
        let shortcut = HomeShortcut(id: "1", name: "Kitchen Light")
        XCTAssertNil(shortcut.emoji)
        XCTAssertEqual(shortcut.title, "Kitchen Light")
    }

    func testSymbolIsPickedFromSwedishAndEnglishWords() {
        XCTAssertEqual(HomeShortcut(id: "1", name: "Kitchen Light").symbol, "lightbulb.fill")
        XCTAssertEqual(HomeShortcut(id: "1", name: "Tänd lampor").symbol, "lightbulb.fill")
        XCTAssertEqual(HomeShortcut(id: "1", name: "Golvlampa").symbol, "lamp.floor.fill")
        XCTAssertEqual(HomeShortcut(id: "1", name: "Lock the door").symbol, "lock.fill")
        XCTAssertEqual(HomeShortcut(id: "1", name: "God natt").symbol, "moon.stars.fill")
        XCTAssertEqual(HomeShortcut(id: "1", name: "Something else").symbol, "sparkles")
    }

    @MainActor func testToggleStateReadsOnAndOffInBothLanguages() {
        XCTAssertEqual(HomeService.toggleState(from: "on\n"), true)
        XCTAssertEqual(HomeService.toggleState(from: " På "), true)
        XCTAssertEqual(HomeService.toggleState(from: "OFF"), false)
        XCTAssertEqual(HomeService.toggleState(from: "låst"), false)
        XCTAssertNil(HomeService.toggleState(from: "Done"))
        XCTAssertNil(HomeService.toggleState(from: ""))
    }

    @MainActor func testParsesShortcutsListLines() {
        let id = "8F2B7E0C-3D4A-4C1B-9E2F-1A2B3C4D5E6F"
        let shortcut = HomeService.parse("Good Night (with friends) (\(id))")
        XCTAssertEqual(shortcut?.id, id)
        XCTAssertEqual(shortcut?.name, "Good Night (with friends)")
        XCTAssertNil(HomeService.parse("Good Night"))
        XCTAssertNil(HomeService.parse("Good Night (not-an-id)"))
    }
}
