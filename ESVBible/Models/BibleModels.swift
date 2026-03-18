import AppKit
import Foundation
import SwiftUI

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
    let endBook: String?    // nil for single-chapter/same-book ranges
    let endChapter: Int?    // nil for single-chapter references
    let verseEnd: Int?

    // Memberwise init with default nil values keeps all existing call sites unchanged.
    init(book: String, chapter: Int, verseStart: Int? = nil,
         endBook: String? = nil, endChapter: Int? = nil, verseEnd: Int? = nil) {
        precondition(endBook == nil || endChapter != nil,
                     "BibleReference: endBook requires endChapter to also be set")
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.endBook = endBook
        self.endChapter = endChapter
        self.verseEnd = verseEnd
    }

    var displayString: String {
        if let eb = endBook, let ec = endChapter {
            // Cross-book: "John 3:36 – Acts 1:1"
            let startVerse = verseStart.map { ":\($0)" } ?? ""
            let endVerse = verseEnd.map { ":\($0)" } ?? ""
            return "\(book) \(chapter)\(startVerse) \u{2013} \(eb) \(ec)\(endVerse)"
        }
        if let ec = endChapter {
            // Cross-chapter same book: "John 3:36–4:2"
            let sv = verseStart ?? 1
            let ev = verseEnd ?? 1
            return "\(book) \(chapter):\(sv)\u{2013}\(ec):\(ev)"
        }
        // Existing single-chapter logic (unchanged)
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

enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor.systemYellow.withAlphaComponent(0.35)
        case .green: return NSColor.systemGreen.withAlphaComponent(0.35)
        case .blue: return NSColor.systemBlue.withAlphaComponent(0.25)
        case .pink: return NSColor.systemPink.withAlphaComponent(0.3)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.35)
        case .green: return Color.green.opacity(0.35)
        case .blue: return Color.blue.opacity(0.25)
        case .pink: return Color.pink.opacity(0.3)
        }
    }

    var scrubberColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.85)
        case .green: return Color.green.opacity(0.85)
        case .blue: return Color.blue.opacity(0.8)
        case .pink: return Color.pink.opacity(0.85)
        }
    }
}

struct Highlight: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int
    let startCharOffset: Int
    let endCharOffset: Int
    let color: HighlightColor
    let createdAt: Date
}

struct Bookmark: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let createdAt: Date
}

struct Note: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let rtfData: Data
    let createdAt: Date
    var updatedAt: Date
}
