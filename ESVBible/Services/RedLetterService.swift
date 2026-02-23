import Foundation

/// Provides lookup for red-letter (words of Christ) character ranges.
struct RedLetterService {
    static let shared = RedLetterService()

    // book → chapter-string → verse-string → [[start, end], ...]
    private let data: [String: [String: [String: [[Int]]]]]

    private init() {
        guard let url = Bundle.main.url(forResource: "red_letter_ranges", withExtension: "json"),
              let jsonData = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: [String: [[Int]]]]].self, from: jsonData) else {
            data = [:]
            return
        }
        data = raw
    }

    /// Returns the character ranges within the verse text that should be rendered in red.
    /// Each range is a (start, end) pair where start is inclusive and end is exclusive,
    /// matching Swift's String index convention when used with NSRange.
    func redLetterRanges(book: String, chapter: Int, verse: Int) -> [(start: Int, end: Int)] {
        guard let ranges = data[book]?[String(chapter)]?[String(verse)] else { return [] }
        return ranges.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return (start: pair[0], end: pair[1])
        }
    }
}
