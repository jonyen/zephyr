import Foundation

struct Verse: Codable, Identifiable {
    let number: Int
    let text: String
    var id: Int { number }
}

struct Chapter: Codable, Identifiable {
    let number: Int
    let verses: [Verse]
    var id: Int { number }
}

struct Book: Codable, Identifiable {
    let name: String
    let chapters: [Chapter]
    var id: String { name }
}

struct Bible: Codable {
    let books: [Book]
}

struct BibleReference: Equatable, Hashable {
    let book: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?

    var displayString: String {
        if let start = verseStart, let end = verseEnd, start != end {
            return "\(book) \(chapter):\(start)-\(end)"
        } else if let start = verseStart {
            return "\(book) \(chapter):\(start)"
        } else {
            return "\(book) \(chapter)"
        }
    }
}

struct HistoryEntry: Codable, Identifiable {
    let reference: String
    let bookName: String
    let chapter: Int
    let verseStart: Int?
    let verseEnd: Int?
    let timestamp: Date
    var id: String { "\(reference)-\(timestamp.timeIntervalSince1970)" }
}
