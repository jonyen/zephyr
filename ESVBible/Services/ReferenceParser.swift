import Foundation

enum ReferenceParser {
    private static let pattern = #"^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$"#

    static func parse(_ input: String) -> BibleReference? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }

        guard let bookRange = Range(match.range(at: 1), in: trimmed),
              let chapterRange = Range(match.range(at: 2), in: trimmed),
              let chapter = Int(trimmed[chapterRange]) else {
            return nil
        }

        let book = String(trimmed[bookRange])
        var verseStart: Int? = nil
        var verseEnd: Int? = nil

        if match.range(at: 3).location != NSNotFound,
           let range = Range(match.range(at: 3), in: trimmed) {
            verseStart = Int(trimmed[range])
        }
        if match.range(at: 4).location != NSNotFound,
           let range = Range(match.range(at: 4), in: trimmed) {
            verseEnd = Int(trimmed[range])
        }

        return BibleReference(book: book, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd)
    }
}
