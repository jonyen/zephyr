# ESV Bible Reader Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a lightweight macOS SwiftUI app for reading the ESV Bible offline, with verse search and history tracking.

**Architecture:** SwiftUI single-window app. Bible text stored as bundled JSON (~5MB). Reference parser converts user input to book/chapter/verse lookups. History persisted to Application Support as JSON.

**Tech Stack:** Swift, SwiftUI, macOS 14+, Xcode project

---

### Task 1: Scaffold Xcode Project

**Files:**
- Create: `ESVBible/ESVBibleApp.swift`
- Create: `ESVBible/ContentView.swift`
- Create: `ESVBible/Info.plist`
- Create: `ESVBible.xcodeproj/project.pbxproj`

**Step 1: Create project directory structure**

```bash
mkdir -p ESVBible/Resources
mkdir -p ESVBible/Models
mkdir -p ESVBible/Views
mkdir -p ESVBible/Services
mkdir -p ESVBibleTests
```

**Step 2: Create the app entry point**

`ESVBible/ESVBibleApp.swift`:
```swift
import SwiftUI

@main
struct ESVBibleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
    }
}
```

**Step 3: Create placeholder ContentView**

`ESVBible/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("ESV Bible Reader")
            .frame(minWidth: 400, minHeight: 500)
    }
}
```

**Step 4: Generate Xcode project using `swift package init` and convert to app target, OR create the xcodeproj manually**

We'll create the project via Xcode CLI or manually write the pbxproj. Simpler approach: create a `Package.swift` that builds a macOS app, then generate an Xcode project.

Actually — we'll create the full Xcode project structure directly. This is the most reliable approach for a macOS SwiftUI app.

**Step 5: Verify project builds**

Run: `xcodebuild -scheme ESVBible -configuration Debug build`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add ESVBible/ ESVBible.xcodeproj/
git commit -m "feat: scaffold ESV Bible Reader Xcode project"
```

---

### Task 2: Data Models

**Files:**
- Create: `ESVBible/Models/BibleModels.swift`
- Create: `ESVBibleTests/BibleModelsTests.swift`

**Step 1: Write the models test**

`ESVBibleTests/BibleModelsTests.swift`:
```swift
import XCTest
@testable import ESVBible

final class BibleModelsTests: XCTestCase {
    func testVerseDecoding() throws {
        let json = """
        {"number": 16, "text": "For God so loved the world"}
        """.data(using: .utf8)!
        let verse = try JSONDecoder().decode(Verse.self, from: json)
        XCTAssertEqual(verse.number, 16)
        XCTAssertEqual(verse.text, "For God so loved the world")
    }

    func testChapterDecoding() throws {
        let json = """
        {"number": 3, "verses": [{"number": 16, "text": "For God so loved the world"}]}
        """.data(using: .utf8)!
        let chapter = try JSONDecoder().decode(Chapter.self, from: json)
        XCTAssertEqual(chapter.number, 3)
        XCTAssertEqual(chapter.verses.count, 1)
    }

    func testBookDecoding() throws {
        let json = """
        {"name": "John", "chapters": [{"number": 3, "verses": [{"number": 16, "text": "For God so loved the world"}]}]}
        """.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: json)
        XCTAssertEqual(book.name, "John")
        XCTAssertEqual(book.chapters.count, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ESVBible -destination 'platform=macOS'`
Expected: FAIL — types not defined

**Step 3: Write the models**

`ESVBible/Models/BibleModels.swift`:
```swift
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
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ESVBible -destination 'platform=macOS'`
Expected: PASS

**Step 5: Commit**

```bash
git add ESVBible/Models/ ESVBibleTests/
git commit -m "feat: add Bible data models (Verse, Chapter, Book, Reference, History)"
```

---

### Task 3: ESV API Download Script

**Files:**
- Create: `Scripts/download_esv.swift`

**Step 1: Create the download script**

`Scripts/download_esv.swift` — a standalone Swift script that:
1. Takes an API key as a command-line argument
2. Iterates through all 66 books and their chapters
3. Calls `https://api.esv.org/v3/passage/text/?q=BOOK+CHAPTER` for each chapter
4. Parses the response text into verse-level data (splitting on verse number markers)
5. Assembles the full Bible JSON structure
6. Writes `ESVBible/Resources/bible.json`

Key details:
- Use `URLSession` for HTTP requests
- ESV API returns plain text with `[verse_number]` markers when `include-verse-numbers=true`
- Rate limit: add a small delay between requests
- Include a book/chapter count map so we know how many chapters each book has

```swift
#!/usr/bin/env swift

import Foundation

// Full book list with chapter counts
let books: [(name: String, chapters: Int)] = [
    ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36),
    ("Deuteronomy", 34), ("Joshua", 24), ("Judges", 21), ("Ruth", 4),
    ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
    ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10), ("Nehemiah", 13),
    ("Esther", 10), ("Job", 42), ("Psalms", 150), ("Proverbs", 31),
    ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66),
    ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12),
    ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1), ("Jonah", 4),
    ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3),
    ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4),
    ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21),
    ("Acts", 28), ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13),
    ("Galatians", 6), ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4),
    ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
    ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13),
    ("James", 5), ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5),
    ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22)
]
// ... fetches each chapter via API, parses verses, writes bible.json
```

**Step 2: Test the script with one book**

Run: `swift Scripts/download_esv.swift YOUR_API_KEY --test`
Expected: Downloads Genesis 1 and prints JSON for that chapter

**Step 3: Run full download**

Run: `swift Scripts/download_esv.swift YOUR_API_KEY`
Expected: Creates `ESVBible/Resources/bible.json` (~5MB)

**Step 4: Commit**

```bash
git add Scripts/download_esv.swift ESVBible/Resources/bible.json
git commit -m "feat: add ESV download script and bundled bible.json"
```

---

### Task 4: BibleStore Service

**Files:**
- Create: `ESVBible/Services/BibleStore.swift`
- Create: `ESVBibleTests/BibleStoreTests.swift`

**Step 1: Write failing tests**

`ESVBibleTests/BibleStoreTests.swift`:
```swift
import XCTest
@testable import ESVBible

final class BibleStoreTests: XCTestCase {
    var store: BibleStore!

    override func setUp() {
        // Load from test fixture or bundled bible.json
        store = BibleStore()
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

    func testGetChapter() {
        let chapter = store.getChapter(book: "John", chapter: 3)
        XCTAssertNotNil(chapter)
        XCTAssertEqual(chapter?.number, 3)
        XCTAssertFalse(chapter?.verses.isEmpty ?? true)
    }

    func testGetVerse() {
        let verses = store.getVerses(book: "John", chapter: 3, start: 16, end: 16)
        XCTAssertEqual(verses.count, 1)
    }
}
```

**Step 2: Run tests — expect failure**

**Step 3: Implement BibleStore**

`ESVBible/Services/BibleStore.swift`:
```swift
import Foundation

@Observable
class BibleStore {
    private(set) var bible: Bible
    private let abbreviations: [String: String] // maps abbreviation -> full name

    init() {
        // Load bible.json from bundle
        guard let url = Bundle.main.url(forResource: "bible", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bible = try? JSONDecoder().decode(Bible.self, from: data) else {
            fatalError("Could not load bible.json from bundle")
        }
        self.bible = bible
        self.abbreviations = Self.buildAbbreviations(bible.books)
    }

    func findBook(_ query: String) -> Book? {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespaces)
        // Try exact match first
        if let book = bible.books.first(where: { $0.name.lowercased() == normalized }) {
            return book
        }
        // Try abbreviation
        if let fullName = abbreviations[normalized] {
            return bible.books.first(where: { $0.name == fullName })
        }
        // Try prefix match
        return bible.books.first(where: { $0.name.lowercased().hasPrefix(normalized) })
    }

    func getChapter(book: String, chapter: Int) -> Chapter? {
        findBook(book)?.chapters.first(where: { $0.number == chapter })
    }

    func getVerses(book: String, chapter: Int, start: Int, end: Int) -> [Verse] {
        guard let ch = getChapter(book: book, chapter: chapter) else { return [] }
        return ch.verses.filter { $0.number >= start && $0.number <= end }
    }

    private static func buildAbbreviations(_ books: [Book]) -> [String: String] {
        // Common abbreviations map
        let map: [String: String] = [
            "gen": "Genesis", "ex": "Exodus", "exod": "Exodus",
            "lev": "Leviticus", "num": "Numbers", "deut": "Deuteronomy",
            "josh": "Joshua", "judg": "Judges", "rth": "Ruth",
            "1 sam": "1 Samuel", "2 sam": "2 Samuel",
            "1 kgs": "1 Kings", "2 kgs": "2 Kings",
            "1 chr": "1 Chronicles", "2 chr": "2 Chronicles",
            "neh": "Nehemiah", "est": "Esther",
            "ps": "Psalms", "psa": "Psalms", "psalm": "Psalms",
            "prov": "Proverbs", "eccl": "Ecclesiastes",
            "song": "Song of Solomon", "sos": "Song of Solomon",
            "isa": "Isaiah", "jer": "Jeremiah", "lam": "Lamentations",
            "ezek": "Ezekiel", "dan": "Daniel", "hos": "Hosea",
            "ob": "Obadiah", "mic": "Micah", "nah": "Nahum",
            "hab": "Habakkuk", "zeph": "Zephaniah", "hag": "Haggai",
            "zech": "Zechariah", "mal": "Malachi",
            "matt": "Matthew", "mk": "Mark", "lk": "Luke", "jn": "John",
            "rom": "Romans", "1 cor": "1 Corinthians", "2 cor": "2 Corinthians",
            "gal": "Galatians", "eph": "Ephesians", "phil": "Philippians",
            "col": "Colossians", "1 thess": "1 Thessalonians",
            "2 thess": "2 Thessalonians", "1 tim": "1 Timothy",
            "2 tim": "2 Timothy", "tit": "Titus", "phm": "Philemon",
            "heb": "Hebrews", "jas": "James", "1 pet": "1 Peter",
            "2 pet": "2 Peter", "1 jn": "1 John", "2 jn": "2 John",
            "3 jn": "3 John", "rev": "Revelation"
        ]
        return map
    }
}
```

**Step 4: Run tests — expect pass**

**Step 5: Commit**

```bash
git add ESVBible/Services/ ESVBibleTests/
git commit -m "feat: add BibleStore service with abbreviation lookup"
```

---

### Task 5: Reference Parser

**Files:**
- Create: `ESVBible/Services/ReferenceParser.swift`
- Create: `ESVBibleTests/ReferenceParserTests.swift`

**Step 1: Write failing tests**

`ESVBibleTests/ReferenceParserTests.swift`:
```swift
import XCTest
@testable import ESVBible

final class ReferenceParserTests: XCTestCase {
    func testSimpleBookChapterVerse() {
        let ref = ReferenceParser.parse("John 3:16")
        XCTAssertEqual(ref?.book, "John")
        XCTAssertEqual(ref?.chapter, 3)
        XCTAssertEqual(ref?.verseStart, 16)
        XCTAssertNil(ref?.verseEnd)
    }

    func testBookChapterOnly() {
        let ref = ReferenceParser.parse("Genesis 1")
        XCTAssertEqual(ref?.book, "Genesis")
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertNil(ref?.verseStart)
    }

    func testVerseRange() {
        let ref = ReferenceParser.parse("Romans 8:28-30")
        XCTAssertEqual(ref?.book, "Romans")
        XCTAssertEqual(ref?.chapter, 8)
        XCTAssertEqual(ref?.verseStart, 28)
        XCTAssertEqual(ref?.verseEnd, 30)
    }

    func testNumberedBook() {
        let ref = ReferenceParser.parse("1 Corinthians 13:4")
        XCTAssertEqual(ref?.book, "1 Corinthians")
        XCTAssertEqual(ref?.chapter, 13)
        XCTAssertEqual(ref?.verseStart, 4)
    }

    func testAbbreviation() {
        let ref = ReferenceParser.parse("Gen 1:1")
        XCTAssertEqual(ref?.book, "Gen")
        XCTAssertEqual(ref?.chapter, 1)
        XCTAssertEqual(ref?.verseStart, 1)
    }

    func testInvalidInput() {
        let ref = ReferenceParser.parse("not a reference")
        XCTAssertNil(ref)
    }
}
```

**Step 2: Run tests — expect failure**

**Step 3: Implement parser**

`ESVBible/Services/ReferenceParser.swift`:
```swift
import Foundation

enum ReferenceParser {
    // Matches: "1 John 3:16-18", "Genesis 1", "John 3:16", "Gen 1:1"
    // Group 1: book name (may start with digit + space)
    // Group 2: chapter number
    // Group 3: optional start verse
    // Group 4: optional end verse
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
```

**Step 4: Run tests — expect pass**

**Step 5: Commit**

```bash
git add ESVBible/Services/ReferenceParser.swift ESVBibleTests/ReferenceParserTests.swift
git commit -m "feat: add Bible reference parser with abbreviation and range support"
```

---

### Task 6: History Manager

**Files:**
- Create: `ESVBible/Services/HistoryManager.swift`
- Create: `ESVBibleTests/HistoryManagerTests.swift`

**Step 1: Write failing tests**

```swift
import XCTest
@testable import ESVBible

final class HistoryManagerTests: XCTestCase {
    var manager: HistoryManager!
    var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        manager = HistoryManager(storageURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testAddEntry() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref)
        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.reference, "John 3:16")
    }

    func testMaxEntries() {
        for i in 1...110 {
            let ref = BibleReference(book: "Genesis", chapter: i % 50 + 1, verseStart: 1, verseEnd: nil)
            manager.addEntry(for: ref)
        }
        XCTAssertEqual(manager.entries.count, 100)
    }

    func testPersistence() {
        let ref = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
        manager.addEntry(for: ref)

        let manager2 = HistoryManager(storageURL: tempURL)
        XCTAssertEqual(manager2.entries.count, 1)
    }
}
```

**Step 2: Run tests — expect failure**

**Step 3: Implement HistoryManager**

`ESVBible/Services/HistoryManager.swift`:
```swift
import Foundation

@Observable
class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    private let storageURL: URL
    private let maxEntries = 100

    init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("ESVBible", isDirectory: true)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.storageURL = appDir.appendingPathComponent("history.json")
        }
        load()
    }

    func addEntry(for ref: BibleReference) {
        let entry = HistoryEntry(
            reference: ref.displayString,
            bookName: ref.book,
            chapter: ref.chapter,
            verseStart: ref.verseStart,
            verseEnd: ref.verseEnd,
            timestamp: Date()
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func clearHistory() {
        entries.removeAll()
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }
}
```

**Step 4: Run tests — expect pass**

**Step 5: Commit**

```bash
git add ESVBible/Services/HistoryManager.swift ESVBibleTests/HistoryManagerTests.swift
git commit -m "feat: add HistoryManager with persistence and max-entry cap"
```

---

### Task 7: Reading Pane View

**Files:**
- Create: `ESVBible/Views/ReadingPaneView.swift`

**Step 1: Implement the reading pane**

`ESVBible/Views/ReadingPaneView.swift`:
```swift
import SwiftUI

struct ReadingPaneView: View {
    let chapter: Chapter
    let bookName: String
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Chapter heading
                    Text("\(bookName) \(chapter.number)")
                        .font(.title)
                        .fontWeight(.semibold)
                        .padding(.bottom, 16)

                    // Verses as flowing text
                    ForEach(chapter.verses) { verse in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(verse.number)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .baselineOffset(6)

                            Text(verse.text)
                                .font(.system(size: 16, design: .serif))
                                .lineSpacing(6)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(
                            isHighlighted(verse.number)
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .cornerRadius(4)
                        .id(verse.number)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                if let start = highlightVerseStart {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(start, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func isHighlighted(_ verseNumber: Int) -> Bool {
        guard let start = highlightVerseStart else { return false }
        let end = highlightVerseEnd ?? start
        return verseNumber >= start && verseNumber <= end
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ESVBible -configuration Debug`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/Views/ReadingPaneView.swift
git commit -m "feat: add ReadingPaneView with verse highlighting and scroll-to"
```

---

### Task 8: History Sidebar View

**Files:**
- Create: `ESVBible/Views/HistorySidebarView.swift`

**Step 1: Implement the sidebar**

`ESVBible/Views/HistorySidebarView.swift`:
```swift
import SwiftUI

struct HistorySidebarView: View {
    let entries: [HistoryEntry]
    let onSelect: (HistoryEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !entries.isEmpty {
                    Button("Clear") {
                        onClear()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if entries.isEmpty {
                Text("No history yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                List(entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.reference)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add ESVBible/Views/HistorySidebarView.swift
git commit -m "feat: add HistorySidebarView with selection and clear support"
```

---

### Task 9: Main ContentView (Assemble Everything)

**Files:**
- Modify: `ESVBible/ContentView.swift`
- Modify: `ESVBible/ESVBibleApp.swift`

**Step 1: Implement the full ContentView**

`ESVBible/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    @State private var bibleStore = BibleStore()
    @State private var historyManager = HistoryManager()
    @State private var searchText = ""
    @State private var currentBookName: String = "Genesis"
    @State private var currentChapter: Chapter?
    @State private var highlightStart: Int? = nil
    @State private var highlightEnd: Int? = nil
    @State private var showSidebar = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(showSidebar ? .all : .detailOnly)) {
            HistorySidebarView(
                entries: historyManager.entries,
                onSelect: { entry in
                    navigateToHistory(entry)
                },
                onClear: {
                    historyManager.clearHistory()
                }
            )
            .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 250)
        } detail: {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search (e.g. John 3:16)", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(.bar)

                Divider()

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                }

                // Reading pane
                if let chapter = currentChapter {
                    ReadingPaneView(
                        chapter: chapter,
                        bookName: currentBookName,
                        highlightVerseStart: highlightStart,
                        highlightVerseEnd: highlightEnd
                    )

                    Divider()

                    // Chapter navigation
                    HStack {
                        Button {
                            navigateChapter(delta: -1)
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .disabled(!canNavigate(delta: -1))

                        Spacer()

                        Text("\(currentBookName) \(currentChapter?.number ?? 0)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            navigateChapter(delta: 1)
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .disabled(!canNavigate(delta: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
                } else {
                    ContentUnavailableView("Search for a passage",
                        systemImage: "book",
                        description: Text("Enter a reference like \"John 3:16\" or \"Genesis 1\""))
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            // Load Genesis 1 by default
            navigateTo(book: "Genesis", chapter: 1, verseStart: nil, verseEnd: nil, addToHistory: false)
        }
    }

    private func performSearch() {
        errorMessage = nil
        guard let ref = ReferenceParser.parse(searchText) else {
            errorMessage = "Could not parse reference. Try \"John 3:16\" or \"Genesis 1\"."
            return
        }
        navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
    }

    private func navigateTo(book: String, chapter: Int, verseStart: Int?, verseEnd: Int?, addToHistory: Bool) {
        guard let foundBook = bibleStore.findBook(book) else {
            errorMessage = "Book not found: \(book)"
            return
        }
        guard let ch = foundBook.chapters.first(where: { $0.number == chapter }) else {
            errorMessage = "Chapter \(chapter) not found in \(foundBook.name)"
            return
        }
        currentBookName = foundBook.name
        currentChapter = ch
        highlightStart = verseStart
        highlightEnd = verseEnd
        errorMessage = nil

        if addToHistory {
            let ref = BibleReference(book: foundBook.name, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd)
            historyManager.addEntry(for: ref)
        }
    }

    private func navigateToHistory(_ entry: HistoryEntry) {
        navigateTo(book: entry.bookName, chapter: entry.chapter, verseStart: entry.verseStart, verseEnd: entry.verseEnd, addToHistory: false)
    }

    private func navigateChapter(delta: Int) {
        guard let chapter = currentChapter,
              let book = bibleStore.findBook(currentBookName) else { return }
        let newChapterNum = chapter.number + delta
        if let newChapter = book.chapters.first(where: { $0.number == newChapterNum }) {
            currentChapter = newChapter
            highlightStart = nil
            highlightEnd = nil
        }
        // TODO: cross-book navigation could be added later
    }

    private func canNavigate(delta: Int) -> Bool {
        guard let chapter = currentChapter,
              let book = bibleStore.findBook(currentBookName) else { return false }
        return book.chapters.contains(where: { $0.number == chapter.number + delta })
    }
}
```

**Step 2: Update app entry point with window configuration**

`ESVBible/ESVBibleApp.swift`:
```swift
import SwiftUI

@main
struct ESVBibleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 800, height: 600)
    }
}
```

**Step 3: Build and run**

Run: `xcodebuild build -scheme ESVBible -configuration Debug`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ESVBible/
git commit -m "feat: assemble full UI with search, reading pane, history sidebar, and nav"
```

---

### Task 10: Final Polish and Keyboard Shortcuts

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add keyboard shortcuts**

- `Cmd+L` or `Cmd+K` — focus search bar
- `Cmd+[` / `Cmd+]` — previous/next chapter
- `Cmd+Shift+H` — toggle sidebar

**Step 2: Add subtle animations for view transitions**

**Step 3: Build and verify**

**Step 4: Commit**

```bash
git add ESVBible/
git commit -m "feat: add keyboard shortcuts and polish"
```
