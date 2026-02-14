import XCTest
@testable import ESVBible

final class BibleModelsTests: XCTestCase {
    func testVerseDecoding() throws {
        let json = """
        {"number": 16, "text": "For God so loved the world"}
        """.data(using: .utf8)!
        let verse = try JSONDecoder().decode(Verse.self, from: json)
        XCTAssertEqual(verse.number, 16)
        XCTAssertEqual(verse.text, "For God so loved the world")
    }

    func testChapterDecoding() throws {
        let json = """
        {"number": 3, "verses": [{"number": 16, "text": "For God so loved the world"}]}
        """.data(using: .utf8)!
        let chapter = try JSONDecoder().decode(Chapter.self, from: json)
        XCTAssertEqual(chapter.number, 3)
        XCTAssertEqual(chapter.verses.count, 1)
    }

    func testBookDecoding() throws {
        let json = """
        {"name": "John", "chapters": [{"number": 3, "verses": [{"number": 16, "text": "For God so loved the world"}]}]}
        """.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: json)
        XCTAssertEqual(book.name, "John")
        XCTAssertEqual(book.chapters.count, 1)
    }

    func testBibleReferenceDisplayString() {
        let ref1 = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        XCTAssertEqual(ref1.displayString, "John 3:16")

        let ref2 = BibleReference(book: "Romans", chapter: 8, verseStart: 28, verseEnd: 30)
        XCTAssertEqual(ref2.displayString, "Romans 8:28-30")

        let ref3 = BibleReference(book: "Genesis", chapter: 1, verseStart: nil, verseEnd: nil)
        XCTAssertEqual(ref3.displayString, "Genesis 1")
    }
}
