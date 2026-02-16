import XCTest
@testable import ESVBible

final class HighlightManagerTests: XCTestCase {
    var manager: HighlightManager!
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = HighlightManager(storageDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func sampleRTFData(_ text: String) -> Data {
        let attrStr = NSAttributedString(string: text)
        return try! attrStr.data(
            from: NSRange(location: 0, length: attrStr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    func testAddNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Test"))
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertEqual(manager.notes.first?.book, "John")
        XCTAssertEqual(manager.notes.first?.verseStart, 16)
        XCTAssertEqual(manager.notes.first?.verseEnd, 18)
    }

    func testUpdateNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Original"))
        let noteID = manager.notes.first!.id
        let newData = sampleRTFData("Updated")
        manager.updateNote(id: noteID, rtfData: newData)
        XCTAssertEqual(manager.notes.first?.rtfData, newData)
    }

    func testRemoveNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Test"))
        let noteID = manager.notes.first!.id
        manager.removeNote(id: noteID)
        XCTAssertEqual(manager.notes.count, 0)
    }

    func testNotesForChapter() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Note 1"))
        manager.addNote(book: "John", chapter: 5, verseStart: 1, verseEnd: 1, rtfData: sampleRTFData("Note 2"))
        let ch3Notes = manager.notes(forBook: "John", chapter: 3)
        XCTAssertEqual(ch3Notes.count, 1)
        XCTAssertEqual(ch3Notes.first?.verseStart, 16)
    }

    func testNotesPersistence() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Persisted"))
        let manager2 = HighlightManager(storageDirectory: tempDir)
        XCTAssertEqual(manager2.notes.count, 1)
        XCTAssertEqual(manager2.notes.first?.book, "John")
    }
}
