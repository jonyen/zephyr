import XCTest
@testable import ESVBible

final class BibleStoreTests: XCTestCase {
    var store: BibleStore!

    override func setUp() {
        let testBible = Bible(books: [
            Book(name: "Genesis", chapters: [
                Chapter(number: 1, verses: [
                    Verse(number: 1, text: "In the beginning, God created the heavens and the earth.")
                ])
            ]),
            Book(name: "John", chapters: [
                Chapter(number: 3, verses: [
                    Verse(number: 16, text: "For God so loved the world")
                ])
            ])
        ])
        store = BibleStore(bible: testBible)
    }

    func testFindBook() {
        let book = store.findBook("Genesis")
        XCTAssertNotNil(book)
        XCTAssertEqual(book?.name, "Genesis")
    }

    func testFindBookByAbbreviation() {
        let book = store.findBook("Gen")
        XCTAssertNotNil(book)
        XCTAssertEqual(book?.name, "Genesis")
    }

    func testFindBookCaseInsensitive() {
        let book = store.findBook("genesis")
        XCTAssertNotNil(book)
        XCTAssertEqual(book?.name, "Genesis")
    }

    func testGetChapter() {
        let chapter = store.getChapter(bookName: "John", chapter: 3)
        XCTAssertNotNil(chapter)
        XCTAssertEqual(chapter?.number, 3)
    }

    func testGetVerses() {
        let verses = store.getVerses(bookName: "John", chapter: 3, start: 16, end: 16)
        XCTAssertEqual(verses.count, 1)
        XCTAssertEqual(verses.first?.text, "For God so loved the world")
    }

    func testFindBookNotFound() {
        let book = store.findBook("Nonexistent")
        XCTAssertNil(book)
    }
}
