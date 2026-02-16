import Foundation

@Observable
class HighlightManager {
    private(set) var highlights: [Highlight] = []
    private(set) var bookmarks: [Bookmark] = []
    private(set) var notes: [Note] = []
    private let highlightsURL: URL
    private let bookmarksURL: URL
    private let notesURL: URL

    init(storageDirectory: URL? = nil) {
        let dir: URL
        if let url = storageDirectory {
            dir = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("Zephyr", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.highlightsURL = dir.appendingPathComponent("highlights.json")
        self.bookmarksURL = dir.appendingPathComponent("bookmarks.json")
        self.notesURL = dir.appendingPathComponent("notes.json")
        loadHighlights()
        loadBookmarks()
        loadNotes()
    }

    // MARK: - Highlights

    func addHighlight(book: String, chapter: Int, verse: Int, startChar: Int, endChar: Int, color: HighlightColor) {
        let highlight = Highlight(
            id: UUID(),
            book: book,
            chapter: chapter,
            verse: verse,
            startCharOffset: startChar,
            endCharOffset: endChar,
            color: color,
            createdAt: Date()
        )
        highlights.append(highlight)
        saveHighlights()
    }

    func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
        saveHighlights()
    }

    func highlights(forBook book: String, chapter: Int) -> [Highlight] {
        highlights.filter { $0.book == book && $0.chapter == chapter }
    }

    func removeHighlights(book: String, chapter: Int, verse: Int, startChar: Int, endChar: Int) {
        highlights.removeAll { h in
            h.book == book && h.chapter == chapter && h.verse == verse &&
            h.startCharOffset < endChar && h.endCharOffset > startChar
        }
        saveHighlights()
    }

    // MARK: - Bookmarks

    func toggleBookmark(book: String, chapter: Int) {
        if let index = bookmarks.firstIndex(where: { $0.book == book && $0.chapter == chapter }) {
            bookmarks.remove(at: index)
        } else {
            let bookmark = Bookmark(
                id: UUID(),
                book: book,
                chapter: chapter,
                createdAt: Date()
            )
            bookmarks.append(bookmark)
        }
        saveBookmarks()
    }

    func isBookmarked(book: String, chapter: Int) -> Bool {
        bookmarks.contains { $0.book == book && $0.chapter == chapter }
    }

    // MARK: - Notes

    func addNote(book: String, chapter: Int, verseStart: Int, verseEnd: Int, rtfData: Data) {
        let note = Note(
            id: UUID(),
            book: book,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            rtfData: rtfData,
            createdAt: Date(),
            updatedAt: Date()
        )
        notes.append(note)
        saveNotes()
    }

    func updateNote(id: UUID, rtfData: Data) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index] = Note(
            id: notes[index].id,
            book: notes[index].book,
            chapter: notes[index].chapter,
            verseStart: notes[index].verseStart,
            verseEnd: notes[index].verseEnd,
            rtfData: rtfData,
            createdAt: notes[index].createdAt,
            updatedAt: Date()
        )
        saveNotes()
    }

    func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }

    func notes(forBook book: String, chapter: Int) -> [Note] {
        notes.filter { $0.book == book && $0.chapter == chapter }
    }

    // MARK: - Persistence

    private func saveHighlights() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(highlights) else { return }
        try? data.write(to: highlightsURL, options: .atomic)
    }

    private func loadHighlights() {
        guard let data = try? Data(contentsOf: highlightsURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        highlights = (try? decoder.decode([Highlight].self, from: data)) ?? []
    }

    private func saveBookmarks() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(bookmarks) else { return }
        try? data.write(to: bookmarksURL, options: .atomic)
    }

    private func loadBookmarks() {
        guard let data = try? Data(contentsOf: bookmarksURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        bookmarks = (try? decoder.decode([Bookmark].self, from: data)) ?? []
    }

    private func saveNotes() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: notesURL, options: .atomic)
    }

    private func loadNotes() {
        guard let data = try? Data(contentsOf: notesURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        notes = (try? decoder.decode([Note].self, from: data)) ?? []
    }
}
