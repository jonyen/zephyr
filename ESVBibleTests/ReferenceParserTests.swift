import XCTest
@testable import ESVBible

final class ReferenceParserTests: XCTestCase {
    func testSimpleBookChapterVerse() {
        let ref = ReferenceParser.parse("John 3:16")
        XCTAssertEqual(ref?.book, "John")
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verseStart, 16)
        XCTAssertNil(ref?.verseEnd)
    }

    func testBookChapterOnly() {
        let ref = ReferenceParser.parse("Genesis 1")
        XCTAssertEqual(ref?.book, "Genesis")
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertNil(ref?.verseStart)
    }

    func testVerseRange() {
        let ref = ReferenceParser.parse("Romans 8:28-30")
        XCTAssertEqual(ref?.book, "Romans")
        XCTAssertEqual(ref?.chapter, 8)
        XCTAssertEqual(ref?.verseStart, 28)
        XCTAssertEqual(ref?.verseEnd, 30)
    }

    func testNumberedBook() {
        let ref = ReferenceParser.parse("1 Corinthians 13:4")
        XCTAssertEqual(ref?.book, "1 Corinthians")
        XCTAssertEqual(ref?.chapter, 13)
        XCTAssertEqual(ref?.verseStart, 4)
    }

    func testAbbreviation() {
        let ref = ReferenceParser.parse("Gen 1:1")
        XCTAssertEqual(ref?.book, "Gen")
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertEqual(ref?.verseStart, 1)
    }

    func testInvalidInput() {
        let ref = ReferenceParser.parse("not a reference")
        XCTAssertNil(ref)
    }

    func testSongOfSolomon() {
        let ref = ReferenceParser.parse("Song of Solomon 2:1")
        XCTAssertEqual(ref?.book, "Song of Solomon")
        XCTAssertEqual(ref?.chapter, 2)
        XCTAssertEqual(ref?.verseStart, 1)
    }
}
