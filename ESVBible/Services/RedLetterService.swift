import Foundation

/// Provides lookup for red-letter (words of Christ) verses.
struct RedLetterService {
    static let shared = RedLetterService()

    // book name -> chapter number -> set of verse numbers
    private let data: [String: [String: Set<Int>]]

    private init() {
        guard let url = Bundle.main.url(forResource: "red_letter_verses", withExtension: "json"),
              let jsonData = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: [Int]]].self, from: jsonData) else {
            data = [:]
            return
        }
        var result: [String: [String: Set<Int>]] = [:]
        for (book, chapters) in raw {
            var chapterSets: [String: Set<Int>] = [:]
            for (chapter, verses) in chapters {
                chapterSets[chapter] = Set(verses)
            }
            result[book] = chapterSets
        }
        data = result
    }

    func isRedLetter(book: String, chapter: Int, verse: Int) -> Bool {
        data[book]?[String(chapter)]?.contains(verse) ?? false
    }
}
