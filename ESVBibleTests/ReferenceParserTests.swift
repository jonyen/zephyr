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

    // Format 2: cross-chapter same book
    func testCrossChapterRange() {
        let ref = ReferenceParser.parse("John 3:36-4:2")
        XCTAssertEqual(ref?.book, "John")
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verseStart, 36)
        XCTAssertNil(ref?.endBook)
        XCTAssertEqual(ref?.endChapter, 4)
        XCTAssertEqual(ref?.verseEnd, 2)
    }

    func testCrossChapterRangeInvalidOrder() {
        XCTAssertNil(ReferenceParser.parse("John 4:2-3:36"))
    }

    // Format 3: cross-book
    func testCrossBookRange() {
        let ref = ReferenceParser.parse("John 3:36 - Acts 1:1")
        XCTAssertEqual(ref?.book, "John")
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verseStart, 36)
        XCTAssertEqual(ref?.endBook, "Acts")
        XCTAssertEqual(ref?.endChapter, 1)
        XCTAssertEqual(ref?.verseEnd, 1)
    }

    func testCrossBookRangeWithNumberedBook() {
        let ref = ReferenceParser.parse("1 Corinthians 13:1 - 1 Corinthians 13:13")
        XCTAssertEqual(ref?.book, "1 Corinthians")
        XCTAssertEqual(ref?.endBook, "1 Corinthians")
        XCTAssertEqual(ref?.endChapter, 13)
        XCTAssertEqual(ref?.verseEnd, 13)
    }

    // Format 1 still works
    func testExistingFormatsUnchanged() {
        XCTAssertEqual(ReferenceParser.parse("Romans 8:28-30")?.verseEnd, 30)
        XCTAssertNil(ReferenceParser.parse("Romans 8:28-30")?.endChapter)
        XCTAssertNil(ReferenceParser.parse("Romans 8:28-30")?.endBook)
    }

    // parseMultiple tests
    func testParseMultipleTwoRefs() {
        let refs = ReferenceParser.parseMultiple("Genesis 1, Matthew 3")
        XCTAssertEqual(refs?.count, 2)
        XCTAssertEqual(refs?[0].book, "Genesis")
        XCTAssertEqual(refs?[0].chapter, 1)
        XCTAssertEqual(refs?[1].book, "Matthew")
        XCTAssertEqual(refs?[1].chapter, 3)
    }

    func testParseMultipleSingleRef() {
        let refs = ReferenceParser.parseMultiple("John 3:16")
        XCTAssertEqual(refs?.count, 1)
        XCTAssertEqual(refs?[0].verseStart, 16)
    }

    func testParseMultipleReturnsNilOnBadSegment() {
        XCTAssertNil(ReferenceParser.parseMultiple("Genesis 1, not a reference"))
    }

    func testParseMultipleFiltersEmptySegments() {
        let refs = ReferenceParser.parseMultiple("Genesis 1,, Matthew 3")
        XCTAssertEqual(refs?.count, 2)
    }

    func testParseMultipleNilOnEmptyInput() {
        XCTAssertNil(ReferenceParser.parseMultiple(""))
        XCTAssertNil(ReferenceParser.parseMultiple("   "))
    }
}
