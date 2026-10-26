import XCTest
@testable import DynamicIsland

final class ClipboardHistoryTests: XCTestCase {
    private func text(_ string: String) -> ClipboardItem {
        ClipboardItem(content: .text(string))
    }

    private func texts(_ history: ClipboardHistory) -> [String] {
        history.items.compactMap { item -> String? in
            if case .text(let string) = item.content { return string }
            return nil
        }
    }

    func testNewestComesFirst() {
        var history = ClipboardHistory()
        history.add(text("one"))
        history.add(text("two"))
        XCTAssertEqual(texts(history), ["two", "one"])
    }

    func testCopyingAgainMovesItToTheTop() {
        var history = ClipboardHistory()
        history.add(text("one"))
        history.add(text("two"))
        history.add(text("one"))
        XCTAssertEqual(texts(history), ["one", "two"], "no duplicates")
    }

    func testWhitespaceIsNotKept() {
        var history = ClipboardHistory()
        XCTAssertFalse(history.add(text("  \n\t")))
        XCTAssertTrue(history.items.isEmpty)
    }

    func testOldestFallsOffAtTheLimit() {
        var history = ClipboardHistory(limit: 3)
        for string in ["a", "b", "c", "d"] { history.add(text(string)) }
        XCTAssertEqual(texts(history), ["d", "c", "b"])
    }

    func testImagesAreKeptAndDeduplicated() {
        var history = ClipboardHistory()
        let image = ClipboardItem(content: .image(Data([1, 2, 3])))
        history.add(image)
        history.add(text("one"))
        history.add(ClipboardItem(content: .image(Data([1, 2, 3]))))
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items.first?.content, .image(Data([1, 2, 3])))
    }

    func testRemoveAndClear() {
        var history = ClipboardHistory()
        let one = text("one")
        history.add(one)
        history.add(text("two"))
        history.remove(id: one.id)
        XCTAssertEqual(texts(history), ["two"])
        history.clear()
        XCTAssertTrue(history.items.isEmpty)
    }
}
