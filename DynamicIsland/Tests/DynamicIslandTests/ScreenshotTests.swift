import XCTest
@testable import DynamicIsland

final class ScreenshotTests: XCTestCase {
    private typealias Shot = ScreenshotService.Screenshot
    private let start = Date(timeIntervalSince1970: 1_000)

    private func shot(_ name: String, _ seconds: TimeInterval) -> Shot {
        Shot(url: URL(fileURLWithPath: "/Users/me/Desktop/\(name)"), date: start.addingTimeInterval(seconds))
    }

    func testPicksTheNewest() {
        let picked = ScreenshotService.newest([shot("a.png", 5), shot("b.png", 9), shot("c.png", 7)],
                                              after: start, current: nil)
        XCTAssertEqual(picked, shot("b.png", 9))
    }

    func testIgnoresScreenshotsFromBeforeLaunch() {
        XCTAssertNil(ScreenshotService.newest([shot("old.png", -60)], after: start, current: nil))
    }

    func testIgnoresTheHiddenFileWrittenBeforeTheRename() {
        XCTAssertNil(ScreenshotService.newest([shot(".Screenshot.png", 5)], after: start, current: nil))
    }

    func testDoesNotRepeatOrGoBackwards() {
        let current = shot("b.png", 9)
        XCTAssertNil(ScreenshotService.newest([current], after: start, current: current), "same file again")
        XCTAssertNil(ScreenshotService.newest([shot("a.png", 5)], after: start, current: current), "older file")
        XCTAssertEqual(ScreenshotService.newest([shot("c.png", 12)], after: start, current: current), shot("c.png", 12))
    }
}
