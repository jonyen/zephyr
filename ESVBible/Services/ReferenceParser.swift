import Foundation

enum ReferenceParser {
    // Existing single-chapter pattern (Format 1)
    private static let singlePattern = #"^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$"#
    private static let singleRegex = try! NSRegularExpression(pattern: singlePattern)

    // Cross-chapter same-book pattern (Format 2): "Book chap:verse-chap:verse"
    private static let crossChapterPattern = #"^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+):(\d+)-(\d+):(\d+)$"#
    private static let crossChapterRegex = try! NSRegularExpression(pattern: crossChapterPattern)

    static func parse(_ input: String) -> BibleReference? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Format 3: cross-book — requires " - " (space-hyphen-space)
        if trimmed.contains(" - ") {
            if let ref = parseCrossBook(trimmed) { return ref }
            // If Format 3 fails despite " - " being present, fall through to Format 2/1
        }

        // Format 2: cross-chapter same book
        if let ref = parseCrossChapter(trimmed) { return ref }

        // Format 1: existing single-chapter/verse
        return parseSingle(trimmed)
    }

    // MARK: - Format 3: Cross-book

    private static func parseCrossBook(_ input: String) -> BibleReference? {
        // Split on first " - "
        guard let rangeOfSeparator = input.range(of: " - ") else { return nil }
        let leftStr = String(input[input.startIndex..<rangeOfSeparator.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rightStr = String(input[rangeOfSeparator.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Parse each half using Format 1 only (no recursion into Format 3)
        guard let left = parseSingle(leftStr), left.verseStart != nil,
              let right = parseSingle(rightStr), right.verseStart != nil else { return nil }

        return BibleReference(
            book: left.book,
            chapter: left.chapter,
            verseStart: left.verseStart,
            endBook: right.book,
            endChapter: right.chapter,
            verseEnd: right.verseStart  // right half is a single-verse ref; its verseStart is the end verse
        )
    }

    // MARK: - Format 2: Cross-chapter same book

    private static func parseCrossChapter(_ input: String) -> BibleReference? {
        guard let match = crossChapterRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let bookRange = Range(match.range(at: 1), in: input),
              let chRange   = Range(match.range(at: 2), in: input),
              let vsRange   = Range(match.range(at: 3), in: input),
              let ecRange   = Range(match.range(at: 4), in: input),
              let veRange   = Range(match.range(at: 5), in: input),
              let chapter   = Int(input[chRange]),
              let verseStart = Int(input[vsRange]),
              let endChapter = Int(input[ecRange]),
              let verseEnd   = Int(input[veRange]) else { return nil }

        // Reject invalid ordering
        guard endChapter > chapter || (endChapter == chapter && verseEnd >= verseStart) else { return nil }

        return BibleReference(
            book: String(input[bookRange]),
            chapter: chapter,
            verseStart: verseStart,
            endBook: nil,
            endChapter: endChapter,
            verseEnd: verseEnd
        )
    }

    // MARK: - Format 1: Single chapter/verse (existing logic, unchanged)

    private static func parseSingle(_ input: String) -> BibleReference? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let match = singleRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }

        guard let bookRange    = Range(match.range(at: 1), in: trimmed),
              let chapterRange = Range(match.range(at: 2), in: trimmed),
              let chapter      = Int(trimmed[chapterRange]) else { return nil }

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

    // MARK: - parseMultiple

    /// Parses a comma-separated list of references. Returns nil if any segment fails to parse.
    static func parseMultiple(_ input: String) -> [BibleReference]? {
        let segments = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !segments.isEmpty else { return nil }
        var results: [BibleReference] = []
        for segment in segments {
            guard let ref = parse(segment) else { return nil }
            results.append(ref)
        }
        return results
    }
}
