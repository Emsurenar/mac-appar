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

    func testFilesAreKeptAndDeduplicated() {
        var history = ClipboardHistory()
        let file = URL(fileURLWithPath: "/tmp/report.pdf")
        history.add(ClipboardItem(content: .files([file])))
        history.add(text("one"))
        history.add(ClipboardItem(content: .files([file])))
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items.first?.content, .files([file]))
    }

    func testEmptyContentIsNotKept() {
        var history = ClipboardHistory()
        XCTAssertFalse(history.add(ClipboardItem(content: .files([]))))
        XCTAssertFalse(history.add(ClipboardItem(content: .image(Data()))))
        XCTAssertTrue(history.items.isEmpty)
    }

    func testPickingKeepsTheFormatting() {
        var history = ClipboardHistory()
        let snapshot = PasteboardSnapshot(items: [["public.rtf": Data([1]), "public.utf8-plain-text": Data([2])]])
        let item = ClipboardItem(content: .text("bold"), snapshot: snapshot)
        history.add(item)
        history.add(text("other"))
        history.add(ClipboardItem(id: item.id, content: item.content, snapshot: item.snapshot))
        XCTAssertEqual(history.items.first?.snapshot, snapshot)
    }
}
