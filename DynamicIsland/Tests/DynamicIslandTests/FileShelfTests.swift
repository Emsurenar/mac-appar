import XCTest
@testable import DynamicIsland

final class FileShelfTests: XCTestCase {
    private let report = URL(fileURLWithPath: "/Users/me/Desktop/report.pdf")
    private let photo = URL(fileURLWithPath: "/Users/me/Pictures/photo.jpg")

    /// A fresh, empty defaults suite, so the tests never touch the real shelf.
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "DynamicIslandTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        body(defaults)
        defaults.removePersistentDomain(forName: name)
    }

    @MainActor func testStartsEmpty() {
        withDefaults { defaults in
            XCTAssertTrue(FileShelf(defaults: defaults, fileExists: { _ in true }).isEmpty)
        }
    }

    @MainActor func testAddsFilesInOrderWithoutDuplicates() {
        withDefaults { defaults in
            let shelf = FileShelf(defaults: defaults, fileExists: { _ in true })
            shelf.add([report])
            shelf.add([photo, report])
            XCTAssertEqual(shelf.files, [report, photo])
        }
    }

    @MainActor func testIgnoresWebLinks() {
        withDefaults { defaults in
            let shelf = FileShelf(defaults: defaults, fileExists: { _ in true })
            shelf.add([URL(string: "https://example.com")!])
            XCTAssertTrue(shelf.isEmpty)
        }
    }

    @MainActor func testFilesStayAcrossLaunchesUntilRemoved() {
        withDefaults { defaults in
            let shelf = FileShelf(defaults: defaults, fileExists: { _ in true })
            shelf.add([report, photo])
            shelf.remove(report)
            XCTAssertEqual(FileShelf(defaults: defaults, fileExists: { _ in true }).files, [photo])

            shelf.removeAll()
            XCTAssertTrue(FileShelf(defaults: defaults, fileExists: { _ in true }).isEmpty)
        }
    }

    @MainActor func testDeletedFilesLeaveTheShelf() {
        withDefaults { defaults in
            FileShelf(defaults: defaults, fileExists: { _ in true }).add([report, photo])
            let reloaded = FileShelf(defaults: defaults, fileExists: { $0 != self.report })
            XCTAssertEqual(reloaded.files, [photo])
        }
    }

    @MainActor func testShelfTabIsOnByDefault() {
        withDefaults { defaults in
            XCTAssertTrue(AppSettings(defaults: defaults).showShelfTab)
        }
    }
}
