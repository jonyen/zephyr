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

    // MARK: - previewText

    /// A store whose Mark 9 mirrors the ESV's omitted verses: 44 and 46 carry no text.
    private func storeWithOmittedVerses() -> BibleStore {
        BibleStore(bible: Bible(books: [
            Book(name: "Mark", chapters: [
                Chapter(number: 9, verses: [
                    Verse(number: 43, text: "And if your hand causes you to sin, cut it off."),
                    Verse(number: 44, text: ""),
                    Verse(number: 45, text: "And if your foot causes you to sin, cut it off."),
                    Verse(number: 46, text: "")
                ])
            ])
        ]))
    }

    func testPreviewTextForSingleVerse() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16)
        XCTAssertEqual(store.previewText(for: ref), "For God so loved the world")
    }

    func testPreviewTextForBareChapterUsesFirstVerse() {
        let ref = BibleReference(book: "Genesis", chapter: 1)
        XCTAssertEqual(store.previewText(for: ref),
                       "In the beginning, God created the heavens and the earth.")
    }

    func testPreviewTextForRangeUsesStartVerse() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: 18)
        XCTAssertEqual(store.previewText(for: ref), "For God so loved the world")
    }

    func testPreviewTextResolvesAbbreviatedBookName() {
        let ref = BibleReference(book: "Gen", chapter: 1)
        XCTAssertEqual(store.previewText(for: ref),
                       "In the beginning, God created the heavens and the earth.")
    }

    func testPreviewTextSkipsOmittedVerses() {
        // Mark 9:44 is empty in the ESV — preview the next verse that actually has text.
        let ref = BibleReference(book: "Mark", chapter: 9, verseStart: 44)
        XCTAssertEqual(storeWithOmittedVerses().previewText(for: ref),
                       "And if your foot causes you to sin, cut it off.")
    }

    func testPreviewTextIsNilWhenNoVerseWithTextFollows() {
        // 46 is the last verse and is empty — nothing left to preview.
        let ref = BibleReference(book: "Mark", chapter: 9, verseStart: 46)
        XCTAssertNil(storeWithOmittedVerses().previewText(for: ref))
    }

    func testPreviewTextIsNilForMissingChapter() {
        XCTAssertNil(store.previewText(for: BibleReference(book: "John", chapter: 99)))
    }

    func testPreviewTextIsNilForMissingBook() {
        XCTAssertNil(store.previewText(for: BibleReference(book: "Nonexistent", chapter: 1)))
    }

    func testPreviewTextIsNilWhenVerseNumberIsPastEndOfChapter() {
        XCTAssertNil(store.previewText(for: BibleReference(book: "John", chapter: 3, verseStart: 99)))
    }
}
