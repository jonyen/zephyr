# Keyword Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add keyword text search to the ESV Bible app's existing search bar with a pre-built inverted index and inline results dropdown.

**Architecture:** A Python script generates an inverted index JSON mapping words to verse locations. A new `SearchService` loads the index and handles queries. The existing `ContentView` search bar auto-detects reference vs keyword input and shows results in a dropdown. Scoped search (`"Genesis: creation"`) is supported.

**Tech Stack:** SwiftUI, Python 3 (build script), JSON

---

### Task 1: Build the search index generator script

**Files:**
- Create: `Scripts/build_search_index.py`

**Step 1: Write the index generator script**

Create `Scripts/build_search_index.py` that:
- Reads all 66 JSON book files from `ESVBible/Resources/`
- For each verse, normalizes text (lowercase, strip punctuation)
- Splits into words and builds an inverted index: `{word: [{book, chapter, verse, text}]}`
- The `text` field stores the original (non-normalized) verse text for display in results
- Writes output to `ESVBible/Resources/search_index.json`

```python
#!/usr/bin/env python3
"""Build an inverted search index from Bible JSON files."""

import json
import os
import re
import sys

RESOURCES_DIR = os.path.join(os.path.dirname(__file__), "..", "ESVBible", "Resources")

# All 66 book filenames in canonical order
BOOK_FILES = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1Samuel", "2Samuel", "1Kings", "2Kings",
    "1Chronicles", "2Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "SongOfSolomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
    "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John",
    "Acts", "Romans", "1Corinthians", "2Corinthians", "Galatians",
    "Ephesians", "Philippians", "Colossians", "1Thessalonians",
    "2Thessalonians", "1Timothy", "2Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1Peter", "2Peter", "1John", "2John", "3John",
    "Jude", "Revelation",
]


def normalize(text: str) -> list[str]:
    """Lowercase, strip punctuation, split into words."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)
    return [w for w in text.split() if len(w) >= 2]


def main():
    index: dict[str, list[dict]] = {}

    for filename in BOOK_FILES:
        path = os.path.join(RESOURCES_DIR, f"{filename}.json")
        if not os.path.exists(path):
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
            continue

        with open(path, encoding="utf-8") as f:
            book = json.load(f)

        book_name = book["name"]
        for chapter in book["chapters"]:
            ch_num = chapter["number"]
            for verse in chapter["verses"]:
                v_num = verse["number"]
                text = verse["text"]
                words = set(normalize(text))
                entry = {
                    "book": book_name,
                    "chapter": ch_num,
                    "verse": v_num,
                    "text": text,
                }
                for word in words:
                    if word not in index:
                        index[word] = []
                    index[word].append(entry)

    # Sort index keys for deterministic output
    sorted_index = {k: index[k] for k in sorted(index.keys())}

    output_path = os.path.join(RESOURCES_DIR, "search_index.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(sorted_index, f, ensure_ascii=False, separators=(",", ":"))

    total_words = len(sorted_index)
    total_entries = sum(len(v) for v in sorted_index.values())
    print(f"Index built: {total_words} unique words, {total_entries} total entries")
    print(f"Written to: {output_path}")


if __name__ == "__main__":
    main()
```

**Step 2: Run the script and verify output**

Run: `cd /Users/jonyen/Projects/esv-bible && python3 Scripts/build_search_index.py`
Expected: Script prints word/entry counts and creates `ESVBible/Resources/search_index.json`

Verify: `python3 -c "import json; d=json.load(open('ESVBible/Resources/search_index.json')); print(len(d), 'words'); print('faith entries:', len(d.get('faith',[])))"`

**Step 3: Commit**

```bash
git add Scripts/build_search_index.py ESVBible/Resources/search_index.json
git commit -m "feat: add search index generator script and generated index"
```

---

### Task 2: Create SearchService

**Files:**
- Create: `ESVBible/Services/SearchService.swift`
- Test: `ESVBibleTests/SearchServiceTests.swift`

**Step 1: Write the failing tests**

Create `ESVBibleTests/SearchServiceTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class SearchServiceTests: XCTestCase {
    var service: SearchService!

    override func setUp() {
        // Build a small in-memory index for testing
        let index: [String: [SearchService.VerseLocation]] = [
            "faith": [
                SearchService.VerseLocation(book: "Genesis", chapter: 15, verse: 6, text: "And he believed the Lord, and he counted it to him as righteousness."),
                SearchService.VerseLocation(book: "Hebrews", chapter: 11, verse: 1, text: "Now faith is the assurance of things hoped for, the conviction of things not seen."),
            ],
            "love": [
                SearchService.VerseLocation(book: "John", chapter: 3, verse: 16, text: "For God so loved the world, that he gave his only Son."),
                SearchService.VerseLocation(book: "1 John", chapter: 4, verse: 8, text: "Anyone who does not love does not know God, because God is love."),
            ],
            "god": [
                SearchService.VerseLocation(book: "Genesis", chapter: 1, verse: 1, text: "In the beginning, God created the heavens and the earth."),
                SearchService.VerseLocation(book: "John", chapter: 3, verse: 16, text: "For God so loved the world, that he gave his only Son."),
                SearchService.VerseLocation(book: "1 John", chapter: 4, verse: 8, text: "Anyone who does not love does not know God, because God is love."),
            ],
        ]
        service = SearchService(index: index)
    }

    func testSingleWordSearch() {
        let results = service.search(query: "faith")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].book, "Genesis")
        XCTAssertEqual(results[1].book, "Hebrews")
    }

    func testCaseInsensitiveSearch() {
        let results = service.search(query: "Faith")
        XCTAssertEqual(results.count, 2)
    }

    func testMultiWordSearchIntersects() {
        // "god" + "love" should return verses containing both words
        let results = service.search(query: "god love")
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.book == "John" || $0.book == "1 John" })
    }

    func testScopedSearchByBook() {
        // "1 John: love" should only return results from 1 John
        let results = service.search(query: "1 John: love")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].book, "1 John")
    }

    func testNoResults() {
        let results = service.search(query: "xyznonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testEmptyQuery() {
        let results = service.search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testResultLimit() {
        let results = service.search(query: "god", limit: 1)
        XCTAssertEqual(results.count, 1)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project ESVBible.xcodeproj -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -20`
Expected: Compilation errors (SearchService doesn't exist yet)

**Step 3: Write SearchService implementation**

Create `ESVBible/Services/SearchService.swift`:

```swift
import Foundation

@Observable
class SearchService {
    struct VerseLocation: Codable, Equatable, Identifiable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
        var id: String { "\(book).\(chapter).\(verse)" }
    }

    private var index: [String: [VerseLocation]] = [:]
    private var isLoaded = false

    init() {}

    /// Test-only initializer with a pre-built index.
    init(index: [String: [VerseLocation]]) {
        self.index = index
        self.isLoaded = true
    }

    /// Load the index from the bundled JSON file.
    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let url = Bundle.main.url(forResource: "search_index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [VerseLocation]].self, from: data) else {
            print("Error: Could not load search_index.json")
            return
        }
        index = decoded
    }

    /// Search for verses matching the query.
    /// Supports scoped search with "BookName: keyword" syntax.
    /// Multi-word queries intersect results (AND logic).
    func search(query: String, limit: Int = 50) -> [VerseLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        loadIfNeeded()

        // Check for scoped search: "BookName: keyword"
        var bookScope: String? = nil
        var searchTerms: String = trimmed

        if let colonIndex = trimmed.firstIndex(of: ":") {
            let potentialBook = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Only treat as scoped if the part after colon is non-empty
            // and the part before looks like a book name (contains a letter)
            if !afterColon.isEmpty && potentialBook.contains(where: { $0.isLetter }) {
                bookScope = potentialBook
                searchTerms = afterColon
            }
        }

        // Normalize and split search terms
        let words = searchTerms.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }

        // Look up first word
        guard var resultSet = index[words[0]] else { return [] }

        // Intersect with subsequent words
        for word in words.dropFirst() {
            guard let wordResults = index[word] else { return [] }
            let wordIds = Set(wordResults.map { $0.id })
            resultSet = resultSet.filter { wordIds.contains($0.id) }
        }

        // Apply book scope filter
        if let scope = bookScope {
            let scopeLower = scope.lowercased()
            resultSet = resultSet.filter { $0.book.lowercased() == scopeLower }
        }

        return Array(resultSet.prefix(limit))
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project ESVBible.xcodeproj -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All SearchServiceTests pass

**Step 5: Commit**

```bash
git add ESVBible/Services/SearchService.swift ESVBibleTests/SearchServiceTests.swift
git commit -m "feat: add SearchService with inverted index lookup and tests"
```

---

### Task 3: Integrate keyword search into ContentView

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add search state and SearchService**

Add these new state properties to `ContentView`:

```swift
@State private var searchService = SearchService()
@State private var searchResults: [SearchService.VerseLocation] = []
@State private var isKeywordSearch = false
```

**Step 2: Add debounced search with auto-detect**

Replace the `performSearch()` method and add a keyword search method. Update `searchText` to trigger live search via `.onChange`:

Add after the `isSearchFocused` focus state:

```swift
@State private var searchTask: Task<Void, Never>? = nil
```

Add an `.onChange(of: searchText)` modifier on the search `TextField` that debounces and auto-detects:

```swift
.onChange(of: searchText) { _, newValue in
    searchTask?.cancel()
    errorMessage = nil

    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
        searchResults = []
        isKeywordSearch = false
        return
    }

    // If it parses as a reference, clear keyword results
    if ReferenceParser.parse(trimmed) != nil {
        searchResults = []
        isKeywordSearch = false
        return
    }

    // Debounce keyword search
    isKeywordSearch = true
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let results = searchService.search(query: trimmed)
        await MainActor.run {
            searchResults = results
        }
    }
}
```

Update `performSearch()` to handle both modes:

```swift
private func performSearch() {
    errorMessage = nil

    // If we have keyword results showing, navigate to first result on Enter
    if isKeywordSearch && !searchResults.isEmpty {
        let first = searchResults[0]
        dismissSearch()
        navigateTo(book: first.book, chapter: first.chapter, verseStart: first.verse, verseEnd: first.verse, addToHistory: true)
        return
    }

    guard let ref = ReferenceParser.parse(searchText) else {
        errorMessage = "Could not parse reference. Try \"John 3:16\" or \"Genesis 1\"."
        return
    }
    dismissSearch()
    navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
}
```

Update `dismissSearch()` to clear keyword state:

```swift
private func dismissSearch() {
    withAnimation(.spring(duration: 0.2)) {
        isSearchVisible = false
    }
    isSearchFocused = false
    searchResults = []
    isKeywordSearch = false
    searchTask?.cancel()
}
```

**Step 3: Add the inline results dropdown UI**

Inside the `if isSearchVisible` block, after the error message section and before the closing `}` of the VStack, add the results dropdown:

```swift
if !searchResults.isEmpty {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            ForEach(searchResults) { result in
                Button {
                    dismissSearch()
                    navigateTo(book: result.book, chapter: result.chapter, verseStart: result.verse, verseEnd: result.verse, addToHistory: true)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.book) \(result.chapter):\(result.verse)")
                            .font(.subheadline.bold())
                        Text(result.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if result.id != searchResults.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
    }
    .frame(maxHeight: 300)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.separator, lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
}
```

**Step 4: Update placeholder text**

Change the TextField placeholder from:
```swift
TextField("Search (e.g. John 3:16)", text: $searchText)
```
to:
```swift
TextField("Search verses or go to reference...", text: $searchText)
```

**Step 5: Build and test manually**

Run: `xcodebuild build -project ESVBible.xcodeproj -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: integrate keyword search into search bar with inline results dropdown"
```

---

### Task 4: Add search_index.json to Xcode project bundle

**Files:**
- Modify: `ESVBible.xcodeproj/project.pbxproj` (via Xcode or manually)

**Step 1: Ensure search_index.json is included in the app bundle**

The `search_index.json` file must be listed in the Xcode project's "Copy Bundle Resources" build phase so it's available at runtime via `Bundle.main`.

If the other JSON files (Genesis.json, etc.) are already in the Resources group and copied to the bundle, add `search_index.json` the same way. Check how existing resource files are referenced in `project.pbxproj` and add a matching entry for `search_index.json`.

**Step 2: Verify the file loads at runtime**

Build and run the app. Open the search bar (Cmd+F), type a keyword like "faith". Verify results appear in the dropdown.

**Step 3: Commit**

```bash
git add ESVBible.xcodeproj/project.pbxproj
git commit -m "chore: add search_index.json to Xcode bundle resources"
```

---

### Task 5: End-to-end verification

**Step 1: Build and run**

Run: `xcodebuild build -project ESVBible.xcodeproj -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Run all tests**

Run: `xcodebuild test -project ESVBible.xcodeproj -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests pass

**Step 3: Manual smoke test**

1. Launch app, press Cmd+F
2. Type "John 3:16" → should navigate as a reference (no dropdown)
3. Type "faith" → should show keyword results in dropdown
4. Click a result → should navigate to that verse
5. Type "Genesis: creation" → should show only Genesis results
6. Type "love hope" → should show verses containing both words
7. Press Escape → search dismisses, results clear

**Step 4: Final commit if any fixes needed**

```bash
git add -A && git commit -m "fix: address issues found during smoke testing"
```
