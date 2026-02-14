import XCTest
@testable import ESVBible

final class SearchServiceTests: XCTestCase {
    var searchService: SearchService!
    var bibleStore: BibleStore!

    override func setUp() {
        // Create a small Bible for verse text lookups
        let testBible = Bible(books: [
            Book(name: "Genesis", chapters: [
                Chapter(number: 1, verses: [
                    Verse(number: 1, text: "In the beginning, God created the heavens and the earth."),
                    Verse(number: 2, text: "The earth was without form and void.")
                ]),
                Chapter(number: 15, verses: [
                    Verse(number: 6, text: "And he believed the LORD, and he counted it to him as righteousness.")
                ])
            ]),
            Book(name: "Hebrews", chapters: [
                Chapter(number: 11, verses: [
                    Verse(number: 1, text: "Now faith is the assurance of things hoped for, the conviction of things not seen."),
                    Verse(number: 6, text: "And without faith it is impossible to please him.")
                ])
            ]),
            Book(name: "1 John", chapters: [
                Chapter(number: 4, verses: [
                    Verse(number: 7, text: "Beloved, let us love one another, for love is from God."),
                    Verse(number: 8, text: "Anyone who does not love does not know God, because God is love."),
                    Verse(number: 19, text: "We love because he first loved us.")
                ])
            ]),
            Book(name: "John", chapters: [
                Chapter(number: 3, verses: [
                    Verse(number: 16, text: "For God so loved the world, that he gave his only Son.")
                ])
            ])
        ])
        bibleStore = BibleStore(bible: testBible)

        // Build a search index matching the test Bible data
        let testIndex: [String: [(book: String, chapter: Int, verse: Int)]] = [
            "beginning": [(book: "Genesis", chapter: 1, verse: 1)],
            "god": [
                (book: "Genesis", chapter: 1, verse: 1),
                (book: "1 John", chapter: 4, verse: 7),
                (book: "1 John", chapter: 4, verse: 8),
                (book: "John", chapter: 3, verse: 16)
            ],
            "created": [(book: "Genesis", chapter: 1, verse: 1)],
            "earth": [
                (book: "Genesis", chapter: 1, verse: 1),
                (book: "Genesis", chapter: 1, verse: 2)
            ],
            "void": [(book: "Genesis", chapter: 1, verse: 2)],
            "faith": [
                (book: "Genesis", chapter: 15, verse: 6),
                (book: "Hebrews", chapter: 11, verse: 1),
                (book: "Hebrews", chapter: 11, verse: 6)
            ],
            "believed": [(book: "Genesis", chapter: 15, verse: 6)],
            "righteousness": [(book: "Genesis", chapter: 15, verse: 6)],
            "assurance": [(book: "Hebrews", chapter: 11, verse: 1)],
            "impossible": [(book: "Hebrews", chapter: 11, verse: 6)],
            "love": [
                (book: "1 John", chapter: 4, verse: 7),
                (book: "1 John", chapter: 4, verse: 8),
                (book: "1 John", chapter: 4, verse: 19)
            ],
            "loved": [
                (book: "1 John", chapter: 4, verse: 19),
                (book: "John", chapter: 3, verse: 16)
            ],
            "world": [(book: "John", chapter: 3, verse: 16)],
            "son": [(book: "John", chapter: 3, verse: 16)]
        ]
        searchService = SearchService(index: testIndex)
    }

    func testSingleWordSearch() {
        let results = searchService.search(query: "faith", bibleStore: bibleStore)
        XCTAssertEqual(results.count, 3)
        // Verify results are from the expected books
        let books = results.map { $0.book }
        XCTAssertTrue(books.contains("Genesis"))
        XCTAssertTrue(books.contains("Hebrews"))
    }

    func testCaseInsensitiveSearch() {
        let resultsLower = searchService.search(query: "faith", bibleStore: bibleStore)
        let resultsUpper = searchService.search(query: "FAITH", bibleStore: bibleStore)
        let resultsMixed = searchService.search(query: "Faith", bibleStore: bibleStore)
        XCTAssertEqual(resultsLower.count, resultsUpper.count)
        XCTAssertEqual(resultsLower.count, resultsMixed.count)
        XCTAssertEqual(resultsLower, resultsUpper)
    }

    func testMultiWordSearchIntersection() {
        // "god" AND "created" should only match Genesis 1:1
        let results = searchService.search(query: "god created", bibleStore: bibleStore)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.book, "Genesis")
        XCTAssertEqual(results.first?.chapter, 1)
        XCTAssertEqual(results.first?.verse, 1)
    }

    func testScopedSearch() {
        // "1 John: love" should only return results from 1 John
        let results = searchService.search(query: "1 John: love", bibleStore: bibleStore)
        XCTAssertFalse(results.isEmpty)
        for result in results {
            XCTAssertEqual(result.book, "1 John")
        }
        XCTAssertEqual(results.count, 3)
    }

    func testNoResultsForNonexistentWord() {
        let results = searchService.search(query: "xyznonexistent", bibleStore: bibleStore)
        XCTAssertTrue(results.isEmpty)
    }

    func testEmptyQueryReturnsEmpty() {
        let results = searchService.search(query: "", bibleStore: bibleStore)
        XCTAssertTrue(results.isEmpty)

        let resultsSpaces = searchService.search(query: "   ", bibleStore: bibleStore)
        XCTAssertTrue(resultsSpaces.isEmpty)
    }

    func testResultLimitIsRespected() {
        // "love" has 3 results in our test index; limit to 2
        let results = searchService.search(query: "love", bibleStore: bibleStore, limit: 2)
        XCTAssertEqual(results.count, 2)
    }

    func testVerseTextIsLookedUpFromBibleStore() {
        let results = searchService.search(query: "beginning", bibleStore: bibleStore)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "In the beginning, God created the heavens and the earth.")
    }

    func testResultsAreSortedByCanonicalOrder() {
        // "faith" spans Genesis and Hebrews; Genesis should come first
        let results = searchService.search(query: "faith", bibleStore: bibleStore)
        XCTAssertEqual(results.first?.book, "Genesis")
        XCTAssertEqual(results.last?.book, "Hebrews")
    }

    func testMultiWordNoOverlap() {
        // "faith" and "world" have no verse in common
        let results = searchService.search(query: "faith world", bibleStore: bibleStore)
        XCTAssertTrue(results.isEmpty)
    }

    func testColonInQueryWithInvalidBookFallsBackToKeywordSearch() {
        // "love: god" — "love" is NOT a book name, so the colon should be ignored
        // and the query should be treated as a keyword search for "love" AND "god"
        let results = searchService.search(query: "love: god", bibleStore: bibleStore)
        XCTAssertFalse(results.isEmpty, "Expected results for 'love: god' treated as keyword search")
        for result in results {
            XCTAssertEqual(result.book, "1 John")
        }

        // Verify single keyword with trailing colon also works
        let singleWithColon = searchService.search(query: "faith:", bibleStore: bibleStore)
        XCTAssertEqual(singleWithColon.count, 3, "Trailing colon should not break single-keyword search")
    }
}
