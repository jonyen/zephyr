# Verse Range Tab Design

**Date:** 2026-03-17
**Status:** Approved

## Overview

When a user types a verse range (e.g., `john 3:5-6`) or multiple references (e.g., `genesis 1, Matthew 3`) into the search bar, open a new tab that shows **only** those verses. The new tab is locked to those verses — no surrounding context, no navigation away. This replaces the current behavior of navigating within the current tab for verse-range references.

Single whole-chapter references (e.g., `Genesis 1` with no verse range) continue to navigate in the current tab as today.

---

## 1. Parser Changes

**File:** `ESVBible/Services/ReferenceParser.swift`

Add a new static method:

```swift
static func parseMultiple(_ input: String) -> [BibleReference]?
```

- Splits `input` on commas and trims whitespace from each segment
- Filters out empty/whitespace-only segments before parsing
- If no non-empty segments remain, returns `nil`
- Calls existing `parse()` on each non-empty segment
- Returns `nil` if **any** segment fails to parse
- Returns the array of `BibleReference` values if all succeed
- Existing `parse()` is unchanged

**Triggers for the new tab — evaluated in `ContentView` after calling `parseMultiple()`:**
- 2+ references returned → open verse range tab
- Exactly 1 reference with `verseStart != nil` (single verse **or** verse range) → open verse range tab
- Exactly 1 reference with `verseStart == nil` (whole chapter) → navigate in current tab (existing behavior)

---

## 2. VerseRangeView

**File:** `ESVBible/Views/VerseRangeView.swift`

A new, minimal SwiftUI view. Parameters:
- `references: [BibleReference]`
- `bibleStore: BibleStore`

**Layout:**
- `ScrollView` with `.scrollIndicators(.hidden)`
- `VStack` with a section per reference, top padding of 24pt
- Each section: a header label using `ref.displayString` (from the existing `BibleReference.displayString` computed property) in `.headline` style, followed by verse rows
- Each verse row: verse number in `.caption` style as a superscript-like prefix (e.g., `"5 "`) + verse text in the body font. Both on the same line using an `HStack(alignment: .top)`.
- Sections separated by `Divider` with 24pt vertical padding (matches `ChapterView`)
- Max content width of 700pt centered, horizontal padding of 24pt (matches `ReadingPaneView`)

**Appearance:**
- Reads `@AppStorage("readingTheme")` and `@AppStorage("selectedFont")` so it matches the user's settings
- Background uses `readingTheme.backgroundColor`
- Text color uses `readingTheme.nsTextColor` (wrapped in `Color(...)`)
- No highlights, notes, bookmarks, or navigation controls
- Read-only

**Window title:** join `ref.displayString` for all references with `" · "` separator.
- Single: `"John 3:5–6"` (from `BibleReference.displayString`)
- Multiple: `"Genesis 1 · Matthew 3"` (full names, no abbreviation needed)
- Set via `navigationTitle(windowTitle)` on the view

**Verse lookup per reference:**
- Call `bibleStore.findBook(ref.book)` to get the `Book`
- Find the chapter with `book.chapters.first(where: { $0.number == ref.chapter })`
- If `verseStart` is set: filter `chapter.verses` to those where `verse.number >= verseStart && verse.number <= (verseEnd ?? verseStart)`
- If no verse range: show all verses in the chapter
- If book or chapter not found, show a `Text("Not found")` placeholder in `.secondary` style for that section

---

## 3. ContentView Changes

**File:** `ESVBible/ContentView.swift`

### New state

```swift
@State private var parsedMultiReference: [BibleReference]? = nil
```

### onChange(of: searchText)

Replace the current `ReferenceParser.parse()` block with logic that calls `parseMultiple()` instead.

**Invariant:** `parsedReference`, `parsedMultiReference`, and `isKeywordSearch` are mutually exclusive — exactly one is set at any time (or all are nil/false for empty input). Every branch below must clear the other two before setting its own.

1. Call `ReferenceParser.parseMultiple(trimmed)` → `refs`
2. If `refs == nil` (parse failed entirely): set `parsedReference = nil`, `parsedMultiReference = nil`; fall through to keyword search (existing behavior)
3. If `refs` has 2+ entries → validate each against `bibleStore` (book + chapter must exist); if all valid: set `parsedMultiReference = refs`, `parsedReference = nil`, `isKeywordSearch = false`, cancel search task; if any invalid: set `parsedMultiReference = nil`, `parsedReference = nil`; fall through to keyword search
4. If `refs` has exactly 1 entry with `verseStart != nil` → validate; if valid: set `parsedReference = refs[0]`, `parsedMultiReference = nil`, `isKeywordSearch = false`, cancel search task; if invalid: clear both, fall through to keyword search
5. If `refs` has exactly 1 entry with `verseStart == nil` → validate; if valid: set `parsedReference = refs[0]`, `parsedMultiReference = nil`, `isKeywordSearch = false`, cancel search task; if invalid: clear both, fall through to keyword search

Validation: `bibleStore.findBook(ref.book)?.chapters.first(where: { $0.number == ref.chapter }) != nil`.

### searchResultsList

- For `parsedMultiReference != nil`: show a combined row. Label: joined `ref.displayString` values with `" · "`. Uses same styling as the existing single-reference row (book icon, bold subheadline, return arrow). Tapping calls `openVerseRangeTab(references: parsedMultiReference!)`.
- For single `parsedReference` with `verseStart != nil`: row label is `ref.displayString` (unchanged appearance), but tapping calls `openVerseRangeTab(references: [ref])` instead of `navigateTo`.
- For single `parsedReference` with `verseStart == nil`: row tapping calls `navigateTo` as today.

### performSearch() (Enter key)

Same rules:
- Multi-reference → `openVerseRangeTab`
- Single with `verseStart != nil` → `openVerseRangeTab`
- Single with no verse → `navigateTo` (existing)

### New function

```swift
private func openVerseRangeTab(references: [BibleReference])
```

- Guard `hostWindow != nil`; if nil, set `errorMessage` and return
- Creates `NSHostingController(rootView: VerseRangeView(references: references, bibleStore: bibleStore))`
- Creates `NSWindow(contentViewController: controller)` with same frame size, `styleMask`, `tabbingMode = .preferred`, and `tabbingIdentifier` as the host window
- Calls `host.addTabbedWindow(newWindow, ordered: .above)` and `newWindow.makeKeyAndOrderFront(nil)`
- Calls `dismissSearch()` after opening

### dismissSearch()

Add `parsedMultiReference = nil` alongside the existing cleanup (no other changes needed — `parsedReference` and `searchResults` are already cleared).

---

## 4. Verse Range Spans (Cross-Chapter and Cross-Book)

A single reference can span chapters within the same book or across books, using a hyphen as range separator.

### Model

`BibleReference` gains two optional fields:

```swift
struct BibleReference {
    let book: String        // start book
    let chapter: Int        // start chapter
    let verseStart: Int?
    let endBook: String?    // nil when start/end are in the same book
    let endChapter: Int?    // nil when range is within a single chapter
    let verseEnd: Int?
}
```

All existing callers see `endBook = nil` and `endChapter = nil` — fully backwards compatible.

### Parser (`ReferenceParser.parse()`) extension

The function attempts three formats in the following explicit order. The first successful match wins. Parsing is non-ambiguous because the formats are detected by distinct structural markers before attempting a full match.

**Format 3 (tried first): Cross-book** — `Book chap:verse - Book2 chap:verse`
- e.g., `John 3:36 - Acts 1:1`
- Pre-condition check: input contains ` - ` (literal space-hyphen-space). If not present, skip to Format 2.
- Split on the **first** occurrence of ` - `; trim each half; recursively parse each half using Format 1 only (not Format 3 again, to prevent recursion)
- Left half must parse to a reference with `verseStart != nil`; right half must parse to any valid reference
- Produces: start fields from left half; `endBook`, `endChapter`, `verseEnd` from right half
- Rejected if `BibleStore.globalChapterIndex(book: endBook!, chapter: endChapter!) <= BibleStore.globalChapterIndex(book: book, chapter: chapter)` → return `nil`
- Validation (book + chapter existence) is deferred to `ContentView.onChange`

**Format 2 (tried second): Cross-chapter, same book** — `Book chap:verse-chap:verse`
- e.g., `John 3:36-4:2`
- Pre-condition check: input does not contain ` - ` **OR** Format 3 was attempted and failed. Use regex: `^(.+)\s+(\d+):(\d+)-(\d+):(\d+)$`
- If the regex matches 5 groups, treat as cross-chapter format
- Produces: `book`, `chapter = group2`, `verseStart = group3`, `endBook = nil`, `endChapter = group4`, `verseEnd = group5`
- Rejected if `endChapter < chapter`, or (`endChapter == chapter && verseEnd < verseStart`) → return `nil`

**Format 1 (tried last, existing): Single chapter** — `Book chap` or `Book chap:verse` or `Book chap:verse-verse`
- Existing regex: `^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$`
- No change to logic. This format requires the end of the hyphenated range to be a bare integer (no colon), so it cannot match cross-chapter inputs after Format 2 is tried first.

### `displayString` update

- Cross-chapter same book: `"John 3:36–4:2"`
- Cross-book: `"John 3:36 – Acts 1:1"` (en-dash with spaces)

### VerseRangeView lookup for range refs

When `endChapter != nil` or `endBook != nil`, collect all verses in canonical order from start to end. Build a flat array of `(bookName, chapter, verses)` tuples:

1. Start chapter (`book`, `chapter`): filter to verses with `verse.number >= (verseStart ?? 1)`
2. Intermediate chapters in the start book: iterate `for c in (chapter+1)..<(endChapter ?? (endBook == nil ? chapter : startBookChapterCount+1))` — i.e., all chapters between the start chapter and the end chapter (exclusive on both ends). All verses of each chapter.
3. If `endBook != nil` (cross-book): iterate all books in `BibleStore.bookNames` between start book and end book (exclusive); add all chapters and all verses of each. If a book is missing from `bibleStore`, add a "Not found" placeholder for that book and continue.
4. End chapter (`endBook ?? book`, `endChapter ?? chapter`): filter to verses with `verse.number <= (verseEnd ?? Int.max)`

Display as a single section under header `ref.displayString`. If any individual chapter lookup fails, insert a small "Chapter not found" inline placeholder and continue rendering the rest.

## 5. Edge Cases

- **verseEnd < verseStart within same chapter** (e.g., `John 3:10-5`): parse failure; falls through to keyword search
- **endChapter < chapter** (e.g., `John 4:1-3:5`): parse failure
- **End reference before start in Bible order** (e.g., `Acts 1:1 - John 3:36`): parse failure
- **Verse number out of range** (e.g., `John 3:100`): `VerseRangeView` filters by verse number; zero verses → "Not found" placeholder for that section only

## 6. Out of Scope

- Highlighting or notes in the verse range tab
- Keyboard navigation within the verse range tab
- Saving the verse range tab position to history or closed-tabs stack

---

## Files Changed

| File | Change |
|------|--------|
| `ESVBible/Models/BibleModels.swift` | Add `endBook`, `endChapter` to `BibleReference`; update `displayString` |
| `ESVBible/Services/ReferenceParser.swift` | Extend `parse()` for cross-chapter and cross-book ranges; add `parseMultiple()` |
| `ESVBible/Views/VerseRangeView.swift` | New file |
| `ESVBible/ContentView.swift` | New state, updated search onChange logic, `openVerseRangeTab()`, dismissSearch cleanup |
