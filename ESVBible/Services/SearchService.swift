import Foundation

@Observable
class SearchService {
    /// A search result with location and text for display.
    struct VerseResult: Identifiable, Equatable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String  // looked up from BibleStore at query time
        var id: String { "\(book).\(chapter).\(verse)" }
    }

    /// Internal struct matching the JSON index format (no text).
    private struct IndexEntry: Codable {
        let book: String
        let chapter: Int
        let verse: Int
    }

    private var index: [String: [IndexEntry]] = [:]
    private var isLoaded = false

    init() {}

    /// Test-only initializer with a pre-built index.
    init(index: [String: [(book: String, chapter: Int, verse: Int)]]) {
        self.index = index.mapValues { entries in
            entries.map { IndexEntry(book: $0.book, chapter: $0.chapter, verse: $0.verse) }
        }
        self.isLoaded = true
    }

    /// Load the index from the bundled JSON file.
    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let url = Bundle.main.url(forResource: "search_index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [IndexEntry]].self, from: data) else {
            print("Error: Could not load or parse search_index.json from the app bundle.")
            return
        }
        self.index = decoded
    }

    /// Search for verses matching the query.
    /// - Supports scoped search: "BookName: keyword" limits results to that book
    /// - Multi-word queries intersect results (AND logic)
    /// - Returns VerseResult with text looked up from bibleStore
    func search(query: String, bibleStore: BibleStore, limit: Int = 50) -> [VerseResult] {
        loadIfNeeded()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var bookFilter: String? = nil
        var keywords: [String]

        // Check for scoped search with "BookName: keyword(s)"
        if let colonIndex = trimmed.firstIndex(of: ":") {
            let beforeColon = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Verify the part before the colon is a valid book name
            if !beforeColon.isEmpty && !afterColon.isEmpty && isBookName(beforeColon) {
                bookFilter = resolveBookName(beforeColon)
                keywords = afterColon.lowercased().split(separator: " ").map(String.init)
            } else {
                // Colon present but not a valid book scope — strip non-alphanumeric characters
                // so that e.g. "love: faith" becomes ["love", "faith"] instead of ["love:", "faith"]
                let cleaned = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
                keywords = String(cleaned).lowercased().split(separator: " ").map(String.init)
            }
        } else {
            keywords = trimmed.lowercased().split(separator: " ").map(String.init)
        }

        guard !keywords.isEmpty else { return [] }

        // Look up first keyword to get initial result set
        guard let firstMatches = index[keywords[0]] else { return [] }

        // Convert to a set of verse identifiers for intersection
        var resultSet = Set(firstMatches.map { "\($0.book).\($0.chapter).\($0.verse)" })
        var entriesByID: [String: IndexEntry] = [:]
        for entry in firstMatches {
            entriesByID["\(entry.book).\(entry.chapter).\(entry.verse)"] = entry
        }

        // Intersect with subsequent keywords (AND logic)
        for keyword in keywords.dropFirst() {
            guard let matches = index[keyword] else { return [] }
            let matchSet = Set(matches.map { "\($0.book).\($0.chapter).\($0.verse)" })
            resultSet = resultSet.intersection(matchSet)
            for entry in matches {
                let key = "\(entry.book).\(entry.chapter).\(entry.verse)"
                if entriesByID[key] == nil {
                    entriesByID[key] = entry
                }
            }
        }

        // Apply book filter if scoped search
        if let bookFilter = bookFilter {
            resultSet = resultSet.filter { id in
                guard let entry = entriesByID[id] else { return false }
                return entry.book == bookFilter
            }
        }

        // Convert to sorted array and apply limit
        let sortedIDs = resultSet.sorted { a, b in
            guard let entryA = entriesByID[a], let entryB = entriesByID[b] else { return a < b }
            let indexA = BibleStore.bookNames.firstIndex(of: entryA.book) ?? Int.max
            let indexB = BibleStore.bookNames.firstIndex(of: entryB.book) ?? Int.max
            if indexA != indexB { return indexA < indexB }
            if entryA.chapter != entryB.chapter { return entryA.chapter < entryB.chapter }
            return entryA.verse < entryB.verse
        }

        let limitedIDs = sortedIDs.prefix(limit)

        // Look up verse text from BibleStore
        return limitedIDs.compactMap { id -> VerseResult? in
            guard let entry = entriesByID[id] else { return nil }
            let verses = bibleStore.getVerses(bookName: entry.book, chapter: entry.chapter, start: entry.verse, end: entry.verse)
            let text = verses.first?.text ?? ""
            return VerseResult(book: entry.book, chapter: entry.chapter, verse: entry.verse, text: text)
        }
    }

    // MARK: - Private helpers

    /// Check if a string looks like a book name (exists in BibleStore.bookNames, case-insensitive).
    private func isBookName(_ name: String) -> Bool {
        return resolveBookName(name) != nil
    }

    /// Resolve a book name string to its canonical form.
    private func resolveBookName(_ name: String) -> String? {
        let lower = name.lowercased()
        return BibleStore.bookNames.first { $0.lowercased() == lower }
    }
}
