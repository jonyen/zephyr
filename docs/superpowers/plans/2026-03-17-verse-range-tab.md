# Verse Range Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user types a verse range or multiple references into the search bar, open a new tab that shows only those verses locked to that view.

**Architecture:** Extend `BibleReference` with optional cross-chapter/cross-book range fields, extend `ReferenceParser` to handle three input formats, create a minimal read-only `VerseRangeView`, and update `ContentView` to open a new tab for any reference with a verse constraint.

**Tech Stack:** Swift, SwiftUI, AppKit (NSWindow tabs), XCTest

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `ESVBible/Models/BibleModels.swift` | Modify | Add `endBook`, `endChapter` to `BibleReference`; update `displayString` |
| `ESVBible/Services/ReferenceParser.swift` | Modify | Three-format parse; add `parseMultiple()` |
| `ESVBible/Views/VerseRangeView.swift` | Create | Read-only verse display for one or more references |
| `ESVBible/ContentView.swift` | Modify | New state, updated search logic, `openVerseRangeTab()` |
| `ESVBibleTests/BibleModelsTests.swift` | Modify | Tests for extended `BibleReference` |
| `ESVBibleTests/ReferenceParserTests.swift` | Modify | Tests for new parse formats and `parseMultiple()` |

---

## Task 1: Extend BibleReference

**Files:**
- Modify: `ESVBible/Models/BibleModels.swift:27-42`
- Modify: `ESVBibleTests/BibleModelsTests.swift:66-75`

### Background
`BibleReference` is a `struct` with `Equatable` and `Hashable` conformance. All existing call sites pass `book`, `chapter`, `verseStart`, `verseEnd`. We add two optional fields with default values so no existing call sites need changes.

- [ ] **Step 1: Write failing tests for new `BibleReference` fields and `displayString` variants**

Open `ESVBibleTests/BibleModelsTests.swift` and add these tests inside `BibleModelsTests`:

```swift
func testCrossChapterDisplayString() {
    let ref = BibleReference(book: "John", chapter: 3, verseStart: 36, endBook: nil, endChapter: 4, verseEnd: 2)
    XCTAssertEqual(ref.displayString, "John 3:36\u{2013}4:2")
}

func testCrossBookDisplayString() {
    let ref = BibleReference(book: "John", chapter: 3, verseStart: 36, endBook: "Acts", endChapter: 1, verseEnd: 1)
    XCTAssertEqual(ref.displayString, "John 3:36 \u{2013} Acts 1:1")
}

func testExistingDisplayStringsUnchanged() {
    let ref1 = BibleReference(book: "John", chapter: 3, verseStart: 16, verseEnd: nil)
    XCTAssertEqual(ref1.displayString, "John 3:16")
    let ref2 = BibleReference(book: "Romans", chapter: 8, verseStart: 28, verseEnd: 30)
    XCTAssertEqual(ref2.displayString, "Romans 8:28-30")
    let ref3 = BibleReference(book: "Genesis", chapter: 1, verseStart: nil, verseEnd: nil)
    XCTAssertEqual(ref3.displayString, "Genesis 1")
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -only-testing:ZephyrTests/BibleModelsTests \
  -derivedDataPath build 2>&1 | tail -30
```

Expected: compile error — `BibleReference` has no member `endBook` / `endChapter`.

- [ ] **Step 3: Update `BibleReference` in `ESVBible/Models/BibleModels.swift`**

Replace the existing `BibleReference` struct (lines 27–42) with:

```swift
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
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -only-testing:ZephyrTests/BibleModelsTests \
  -derivedDataPath build 2>&1 | tail -20
```

Expected: All `BibleModelsTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ESVBible/Models/BibleModels.swift ESVBibleTests/BibleModelsTests.swift
git commit -m "feat: extend BibleReference with endBook/endChapter for range spans"
```

---

## Task 2: Extend ReferenceParser — three formats

**Files:**
- Modify: `ESVBible/Services/ReferenceParser.swift`
- Modify: `ESVBibleTests/ReferenceParserTests.swift`

### Background
`ReferenceParser` is a caseless `enum` with a single static `parse(_ input: String) -> BibleReference?`. We extend it to recognise three formats tried in order:

- **Format 3 first** (cross-book): requires ` - ` (space-hyphen-space) in input
- **Format 2 second** (cross-chapter same book): matches `^(.+)\s+(\d+):(\d+)-(\d+):(\d+)$`
- **Format 1 last** (existing single-chapter): existing regex — unchanged

`ReferenceParser` has no access to `BibleStore`, so canonical ordering validation (end must come after start) is deferred to `ContentView`. The parser only checks numeric ordering (endChapter >= chapter for same-book, or just structural validity for cross-book).

- [ ] **Step 1: Write failing tests for new parse formats**

Add to `ESVBibleTests/ReferenceParserTests.swift` inside `ReferenceParserTests`:

```swift
// Format 2: cross-chapter same book
func testCrossChapterRange() {
    let ref = ReferenceParser.parse("John 3:36-4:2")
    XCTAssertEqual(ref?.book, "John")
    XCTAssertEqual(ref?.chapter, 3)
    XCTAssertEqual(ref?.verseStart, 36)
    XCTAssertNil(ref?.endBook)
    XCTAssertEqual(ref?.endChapter, 4)
    XCTAssertEqual(ref?.verseEnd, 2)
}

func testCrossChapterRangeInvalidOrder() {
    XCTAssertNil(ReferenceParser.parse("John 4:2-3:36"))
}

// Format 3: cross-book
func testCrossBookRange() {
    let ref = ReferenceParser.parse("John 3:36 - Acts 1:1")
    XCTAssertEqual(ref?.book, "John")
    XCTAssertEqual(ref?.chapter, 3)
    XCTAssertEqual(ref?.verseStart, 36)
    XCTAssertEqual(ref?.endBook, "Acts")
    XCTAssertEqual(ref?.endChapter, 1)
    XCTAssertEqual(ref?.verseEnd, 1)
}

func testCrossBookRangeWithNumberedBook() {
    let ref = ReferenceParser.parse("1 Corinthians 13:1 - 1 Corinthians 13:13")
    XCTAssertEqual(ref?.book, "1 Corinthians")
    XCTAssertEqual(ref?.endBook, "1 Corinthians")
    XCTAssertEqual(ref?.endChapter, 13)
    XCTAssertEqual(ref?.verseEnd, 13)
}

// Format 1 still works
func testExistingFormatsUnchanged() {
    XCTAssertEqual(ReferenceParser.parse("Romans 8:28-30")?.verseEnd, 30)
    XCTAssertNil(ReferenceParser.parse("Romans 8:28-30")?.endChapter)
    XCTAssertNil(ReferenceParser.parse("Romans 8:28-30")?.endBook)
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -only-testing:ZephyrTests/ReferenceParserTests \
  -derivedDataPath build 2>&1 | tail -30
```

Expected: test failures — new fields don't exist yet.

- [ ] **Step 3: Rewrite `ReferenceParser.swift`**

Replace the entire file content with:

```swift
import Foundation

enum ReferenceParser {
    // Existing single-chapter pattern (Format 1)
    private static let singlePattern = #"^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$"#

    // Cross-chapter same-book pattern (Format 2): "Book chap:verse-chap:verse"
    private static let crossChapterPattern = #"^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+):(\d+)-(\d+):(\d+)$"#

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
              let right = parseSingle(rightStr) else { return nil }

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
        guard let regex = try? NSRegularExpression(pattern: crossChapterPattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
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
        guard let regex = try? NSRegularExpression(pattern: singlePattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
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
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -only-testing:ZephyrTests/ReferenceParserTests \
  -derivedDataPath build 2>&1 | tail -20
```

Expected: All `ReferenceParserTests` pass.

- [ ] **Step 5: Commit**

```bash
git add ESVBible/Services/ReferenceParser.swift ESVBibleTests/ReferenceParserTests.swift
git commit -m "feat: extend ReferenceParser with cross-chapter, cross-book, and multi-reference parsing"
```

---

## Task 3: Add parseMultiple tests

**Files:**
- Modify: `ESVBibleTests/ReferenceParserTests.swift`

- [ ] **Step 1: Add `parseMultiple` tests**

Add to `ReferenceParserTests`:

```swift
func testParseMultipleTwoRefs() {
    let refs = ReferenceParser.parseMultiple("Genesis 1, Matthew 3")
    XCTAssertEqual(refs?.count, 2)
    XCTAssertEqual(refs?[0].book, "Genesis")
    XCTAssertEqual(refs?[0].chapter, 1)
    XCTAssertEqual(refs?[1].book, "Matthew")
    XCTAssertEqual(refs?[1].chapter, 3)
}

func testParseMultipleSingleRef() {
    let refs = ReferenceParser.parseMultiple("John 3:16")
    XCTAssertEqual(refs?.count, 1)
    XCTAssertEqual(refs?[0].verseStart, 16)
}

func testParseMultipleReturnsNilOnBadSegment() {
    XCTAssertNil(ReferenceParser.parseMultiple("Genesis 1, not a reference"))
}

func testParseMultipleFiltersEmptySegments() {
    // Extra comma should not cause failure; empty segments are filtered
    let refs = ReferenceParser.parseMultiple("Genesis 1,, Matthew 3")
    // Double comma produces an empty segment which is filtered, so both valid segments parse
    XCTAssertEqual(refs?.count, 2)
}

func testParseMultipleNilOnEmptyInput() {
    XCTAssertNil(ReferenceParser.parseMultiple(""))
    XCTAssertNil(ReferenceParser.parseMultiple("   "))
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -only-testing:ZephyrTests/ReferenceParserTests \
  -derivedDataPath build 2>&1 | tail -20
```

Expected: All `ReferenceParserTests` pass.

- [ ] **Step 3: Commit**

```bash
git add ESVBibleTests/ReferenceParserTests.swift
git commit -m "test: add parseMultiple tests"
```

---

## Task 4: Create VerseRangeView

**Files:**
- Create: `ESVBible/Views/VerseRangeView.swift`

### Background
This is a minimal read-only view. It takes `[BibleReference]` + `BibleStore`, collects verses for each reference, and renders them. No navigation, no highlights, no notes. Respects `readingTheme` and `selectedFont`.

For references with no range fields (`endBook == nil && endChapter == nil`), the logic is straightforward filtering. For cross-chapter and cross-book ranges, we build a flat list of `(bookName, chapterNumber, [Verse])` sections by iterating canonical chapter order.

The window title is set via `.navigationTitle()`.

- [ ] **Step 1: Create `ESVBible/Views/VerseRangeView.swift`**

```swift
import SwiftUI

struct VerseRangeView: View {
    let references: [BibleReference]
    let bibleStore: BibleStore

    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(references.enumerated()), id: \.offset) { index, ref in
                    referenceSection(ref)

                    if index < references.count - 1 {
                        Divider()
                            .padding(.vertical, 24)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(readingTheme.backgroundColor.ignoresSafeArea())
        .navigationTitle(windowTitle)
        .preferredColorScheme(readingTheme.colorScheme)
    }

    // MARK: - Window title

    private var windowTitle: String {
        references.map { $0.displayString }.joined(separator: " \u{00B7} ")
    }

    // MARK: - Per-reference section

    @ViewBuilder
    private func referenceSection(_ ref: BibleReference) -> some View {
        let sections = collectSections(for: ref)

        VStack(alignment: .leading, spacing: 12) {
            Text(ref.displayString)
                .font(.headline)
                .foregroundStyle(Color(readingTheme.nsTextColor))

            if sections.isEmpty {
                Text("Not found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sections, id: \.id) { section in
                    verseSectionView(section)
                }
            }
        }
    }

    @ViewBuilder
    private func verseSectionView(_ section: VerseSection) -> some View {
        if section.verses.isEmpty {
            Text("Chapter not found")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(section.verses) { verse in
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(verse.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, alignment: .trailing)
                            .padding(.top, 2)
                        Text(verse.text)
                            .font(.custom(selectedFont, size: 16))
                            .foregroundStyle(Color(readingTheme.nsTextColor))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Verse collection

    private struct VerseSection: Identifiable {
        let id: String   // "bookName-chapterNum"
        let verses: [Verse]
    }

    private func collectSections(for ref: BibleReference) -> [VerseSection] {
        if ref.endBook != nil || ref.endChapter != nil {
            return collectRangeSections(for: ref)
        }

        // Simple single-chapter reference
        guard let book = bibleStore.findBook(ref.book),
              let chapter = book.chapters.first(where: { $0.number == ref.chapter }) else {
            return []
        }

        let verses: [Verse]
        if let start = ref.verseStart {
            let end = ref.verseEnd ?? start
            verses = chapter.verses.filter { $0.number >= start && $0.number <= end }
        } else {
            verses = chapter.verses
        }

        return [VerseSection(id: "\(book.name)-\(chapter.number)", verses: verses)]
    }

    private func collectRangeSections(for ref: BibleReference) -> [VerseSection] {
        var result: [VerseSection] = []

        let startBookName = ref.book
        let startChapter = ref.chapter
        let startVerse = ref.verseStart ?? 1

        let endBookName = ref.endBook ?? ref.book
        let endChapter = ref.endChapter ?? ref.chapter
        let endVerse = ref.verseEnd

        // Get all book names from startBook to endBook in canonical order
        let bookNames = BibleStore.bookNames
        guard let startBookIdx = bookNames.firstIndex(of: resolveBookName(startBookName)),
              let endBookIdx   = bookNames.firstIndex(of: resolveBookName(endBookName)),
              startBookIdx <= endBookIdx else {
            return []
        }

        let booksInRange = Array(bookNames[startBookIdx...endBookIdx])

        for (bi, bookName) in booksInRange.enumerated() {
            guard let book = bibleStore.findBook(bookName) else {
                result.append(VerseSection(id: "\(bookName)-missing", verses: []))
                continue
            }

            let isFirstBook = bi == 0
            let isLastBook  = bi == booksInRange.count - 1

            let chapStart = isFirstBook ? startChapter : 1
            let chapEnd   = isLastBook  ? endChapter   : (book.chapters.last?.number ?? 1)

            for chNum in chapStart...chapEnd {
                guard let chapter = book.chapters.first(where: { $0.number == chNum }) else {
                    result.append(VerseSection(id: "\(bookName)-\(chNum)-missing", verses: []))
                    continue
                }

                let verses: [Verse]
                if isFirstBook && chNum == startChapter && isLastBook && chNum == endChapter {
                    // Only chapter in range — apply both start and end filters
                    verses = chapter.verses.filter {
                        $0.number >= startVerse && $0.number <= (endVerse ?? Int.max)
                    }
                } else if isFirstBook && chNum == startChapter {
                    verses = chapter.verses.filter { $0.number >= startVerse }
                } else if isLastBook && chNum == endChapter {
                    verses = chapter.verses.filter { $0.number <= (endVerse ?? Int.max) }
                } else {
                    verses = chapter.verses
                }

                result.append(VerseSection(id: "\(bookName)-\(chNum)", verses: verses))
            }
        }

        return result
    }

    /// Resolves a potentially abbreviated book name to a canonical `BibleStore.bookNames` entry.
    private func resolveBookName(_ name: String) -> String {
        bibleStore.findBook(name)?.name ?? name
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
xcodebuild build -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "(error:|Build succeeded)"
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add ESVBible/Views/VerseRangeView.swift
git commit -m "feat: add VerseRangeView for displaying locked verse ranges in a new tab"
```

---

## Task 5: Update ContentView — search logic and openVerseRangeTab

**Files:**
- Modify: `ESVBible/ContentView.swift`

### Background
Three changes to `ContentView`:
1. Add `@State private var parsedMultiReference: [BibleReference]? = nil`
2. Update `onChange(of: searchText)` to use `parseMultiple()` and enforce mutual exclusivity of `parsedReference`/`parsedMultiReference`/`isKeywordSearch`
3. Add `openVerseRangeTab(references:)` function — mirrors the existing `openTab(at:)` pattern
4. Update `dismissSearch()` to clear `parsedMultiReference`
5. Update `searchResultsList` to show the new combined row and changed tap targets
6. Update `performSearch()` to follow the same rules on Enter

The "new tab" trigger logic:
- `refs.count >= 2` → open verse range tab
- `refs.count == 1 && refs[0].verseStart != nil` → open verse range tab
- `refs.count == 1 && refs[0].verseStart == nil` → navigate in current tab (existing behavior)

Cross-book range validation in `onChange`: after parsing, we check that `globalChapterIndex(endBook) > globalChapterIndex(startBook)`. Note: `globalChapterIndex` requires a canonical book name. Use `bibleStore.findBook(ref.book)?.name` to resolve before calling it.

- [ ] **Step 1: Add `parsedMultiReference` state**

In `ContentView.swift`, add after the existing `@State private var parsedReference: BibleReference? = nil` line (around line 36):

```swift
@State private var parsedMultiReference: [BibleReference]? = nil
```

- [ ] **Step 2: Update `dismissSearch()`**

Find `dismissSearch()` (around line 312). Add `parsedMultiReference = nil` to the cleanup:

```swift
private func dismissSearch() {
    withAnimation(.spring(duration: 0.2)) {
        isSearchVisible = false
    }
    isSearchFocused = false
    searchResults = []
    parsedReference = nil
    parsedMultiReference = nil   // ← add this line
    isKeywordSearch = false
    searchTask?.cancel()
}
```

- [ ] **Step 3: Add `openVerseRangeTab(references:)`**

Add this function near `openTab(at:)` (around line 773):

```swift
private func openVerseRangeTab(references: [BibleReference]) {
    guard let host = hostWindow else {
        errorMessage = "No host window available."
        return
    }
    let controller = NSHostingController(rootView: VerseRangeView(references: references, bibleStore: bibleStore))
    let newWindow = NSWindow(contentViewController: controller)
    newWindow.setContentSize(NSSize(width: max(host.frame.width, 400), height: max(host.frame.height, 500)))
    newWindow.styleMask = host.styleMask
    newWindow.tabbingMode = .preferred
    newWindow.tabbingIdentifier = host.tabbingIdentifier
    host.addTabbedWindow(newWindow, ordered: .above)
    newWindow.makeKeyAndOrderFront(nil)
    dismissSearch()
}
```

- [ ] **Step 4: Replace the `onChange(of: searchText)` reference-parsing block**

Inside `onChange(of: searchText)`, find the block that starts with `if let ref = ReferenceParser.parse(trimmed)` (around line 366). Replace it with:

```swift
// Try to parse as one or more Bible references
if let refs = ReferenceParser.parseMultiple(trimmed), !refs.isEmpty {
    // Validate: all referenced book+chapters must exist (including endBook/endChapter for ranges)
    let allValid = refs.allSatisfy { ref in
        let startOk = bibleStore.findBook(ref.book)?.chapters.first(where: { $0.number == ref.chapter }) != nil
        let endOk: Bool
        if let eb = ref.endBook, let ec = ref.endChapter {
            endOk = bibleStore.findBook(eb)?.chapters.first(where: { $0.number == ec }) != nil
        } else if let ec = ref.endChapter {
            endOk = bibleStore.findBook(ref.book)?.chapters.first(where: { $0.number == ec }) != nil
        } else {
            endOk = true
        }
        return startOk && endOk
    }
    if allValid {
        // Cross-book range canonical ordering check
        let isValidOrder: Bool
        if refs.count == 1, let endBook = refs[0].endBook, let endChapter = refs[0].endChapter {
            let startCanonical = bibleStore.findBook(refs[0].book)?.name ?? refs[0].book
            let endCanonical   = bibleStore.findBook(endBook)?.name ?? endBook
            isValidOrder = BibleStore.globalChapterIndex(book: endCanonical, chapter: endChapter)
                         > BibleStore.globalChapterIndex(book: startCanonical, chapter: refs[0].chapter)
        } else {
            isValidOrder = true
        }

        if isValidOrder {
            searchResults = []
            isKeywordSearch = false
            searchTask?.cancel()

            if refs.count >= 2 {
                parsedMultiReference = refs
                parsedReference = nil
            } else {
                parsedMultiReference = nil
                parsedReference = refs[0]
            }
            return
        }
    }
    // Invalid references — fall through to keyword search
    parsedReference = nil
    parsedMultiReference = nil
}
parsedReference = nil
parsedMultiReference = nil

// Keyword search (existing logic)
isKeywordSearch = true
searchTask = Task {
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    let results = searchService.search(query: trimmed, bibleStore: bibleStore)
    await MainActor.run {
        searchResults = results
    }
}
```

- [ ] **Step 5: Update `searchResultsList` — reference result row**

Find the `if let ref = parsedReference` button block inside `searchResultsList` (around line 429). Replace that entire button with:

```swift
if let refs = parsedMultiReference {
    // Multi-reference row
    Button {
        openVerseRangeTab(references: refs)
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "book.closed")
                .foregroundStyle(Color.accentColor)
                .imageScale(.small)
            Text(refs.map { $0.displayString }.joined(separator: " \u{00B7} "))
                .font(.subheadline.bold())
            Spacer()
            Image(systemName: "return")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    .buttonStyle(.plain)

    if !searchResults.isEmpty { Divider() }
} else if let ref = parsedReference {
    Button {
        if ref.verseStart != nil {
            // Verse reference → open focused tab
            openVerseRangeTab(references: [ref])
        } else {
            // Whole chapter → navigate in current tab
            dismissSearch()
            navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
        }
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "book.closed")
                .foregroundStyle(Color.accentColor)
                .imageScale(.small)
            Text(ref.displayString)
                .font(.subheadline.bold())
            Spacer()
            Image(systemName: "return")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    .buttonStyle(.plain)

    if !searchResults.isEmpty { Divider() }
}
```

Also update the condition that controls `searchResultsList` visibility (around line 416). Change:

```swift
if parsedReference != nil || !searchResults.isEmpty {
```

to:

```swift
if parsedReference != nil || parsedMultiReference != nil || !searchResults.isEmpty {
```

- [ ] **Step 6: Update `performSearch()` — Enter key**

Find `performSearch()` (around line 660). Update the reference navigation at the end:

Replace the final block:
```swift
guard let ref = ReferenceParser.parse(searchText) else { ... }
dismissSearch()
navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
```

With:
```swift
// Multi-reference → open tab
if let refs = parsedMultiReference {
    openVerseRangeTab(references: refs)
    return
}

guard let ref = ReferenceParser.parse(searchText.trimmingCharacters(in: .whitespaces)) else {
    if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
        isKeywordSearch = true
        searchResults = searchService.search(query: searchText.trimmingCharacters(in: .whitespaces), bibleStore: bibleStore)
        if searchResults.isEmpty {
            errorMessage = "No results found."
        }
    } else {
        errorMessage = "Enter a reference or keyword to search."
    }
    return
}

if ref.verseStart != nil {
    openVerseRangeTab(references: [ref])
} else {
    dismissSearch()
    navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
}
```

- [ ] **Step 7: Build to confirm everything compiles**

```bash
xcodebuild build -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "(error:|Build succeeded)"
```

Expected: `Build succeeded`

- [ ] **Step 8: Run all tests**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj -scheme Zephyr \
  -destination 'platform=macOS' -derivedDataPath build 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 9: Manual smoke test**

Launch the app. Verify:
1. Type `John 3:5-6` → search dropdown shows "John 3:5–6" row → press Enter → new tab opens showing only verses 5 and 6 of John 3; no other verses visible
2. Type `Genesis 1, Matthew 3` → dropdown shows "Genesis 1 · Matthew 3" row → tap it → new tab opens with Genesis 1 (all verses) then Matthew 3 (all verses)
3. Type `John 3:36-4:2` → dropdown shows "John 3:36–4:2" → new tab shows John 3 verses 36 to end, then John 4 verses 1-2
4. Type `John 3:36 - Acts 1:1` → new tab shows John 3:36 through Acts 1:1 (all intervening chapters)
5. Type `Genesis 1` (no verse) → existing behavior — navigate in current tab (no new tab)
6. Type keyword like `love` → existing keyword search still works

- [ ] **Step 10: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: open verse ranges and multi-references in a focused new tab"
```
