import XCTest
@testable import ESVBible

final class HistoryManagerTests: XCTestCase {
    var manager: HistoryManager!
    var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        manager = HistoryManager(storageURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testAddEntry() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref)
        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.reference, "John 3:16")
    }

    func testMaxEntries() {
        for i in 1...110 {
            let ref = BibleReference(book: "Genesis", chapter: (i % 50) + 1, verseStart: 1, verseEnd: nil)
            manager.addEntry(for: ref)
        }
        XCTAssertEqual(manager.entries.count, 100)
    }

    func testPersistence() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref)

        let manager2 = HistoryManager(storageURL: tempURL)
        XCTAssertEqual(manager2.entries.count, 1)
        XCTAssertEqual(manager2.entries.first?.reference, "John 3:16")
    }

    func testClearHistory() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref)
        XCTAssertEqual(manager.entries.count, 1)
        manager.clearHistory()
        XCTAssertEqual(manager.entries.count, 0)
    }

    func testNewestFirst() {
        let ref1 = BibleReference(book: "Genesis", chapter: 1, verseStart: 1, verseEnd: nil)
        let ref2 = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref1)
        manager.addEntry(for: ref2)
        XCTAssertEqual(manager.entries.first?.reference, "John 3:16")
    }
}
