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

- Splits `input` on commas, trims whitespace from each segment
- Calls existing `parse()` on each segment
- Returns `nil` if **any** segment fails to parse
- Returns the array of `BibleReference` values if all succeed
- Existing `parse()` is unchanged

**Triggers for the new tab:**
- `parseMultiple` returns 2+ references → open verse range tab
- `parseMultiple` returns exactly 1 reference **with** `verseStart != nil` → open verse range tab
- `parseMultiple` returns exactly 1 reference with no verse → navigate in current tab (existing behavior)

---

## 2. VerseRangeView

**File:** `ESVBible/Views/VerseRangeView.swift`

A new, minimal SwiftUI view. Parameters:
- `references: [BibleReference]`
- `bibleStore: BibleStore`

**Layout:**
- `ScrollView` with `.scrollIndicators(.hidden)`
- `VStack` with a section per reference
- Each section: a header label (e.g., "John 3:5–6") in a small bold style, followed by verse rows
- Each verse row: small superscript-style verse number + verse text
- Sections separated by `Divider`
- Max content width of 700pt (matches `ReadingPaneView`)
- Horizontal padding of 24pt (matches existing views)

**Appearance:**
- Reads `@AppStorage("readingTheme")` and `@AppStorage("selectedFont")` so it matches the user's settings
- No highlights, notes, bookmarks, or navigation controls
- Read-only

**Window title:** derived from references:
- Single: `"John 3:5–6"`
- Multiple: `"Gen 1 · Matt 3"` (abbreviated book names, middle dot separator)

---

## 3. ContentView Changes

**File:** `ESVBible/ContentView.swift`

### New state

```swift
@State private var parsedMultiReference: [BibleReference]? = nil
```

### onChange(of: searchText)

After the existing `ReferenceParser.parse()` call, also call `parseMultiple()`:

- If result has 2+ references → set `parsedMultiReference`, clear `parsedReference`
- If result has 1 reference with verseStart → use existing `parsedReference` path (no change to state), but the tap action opens a new tab instead of navigating in place
- If result has 1 reference with no verse → existing behavior (navigate in current tab)

### searchResultsList

- For `parsedMultiReference != nil`: show a combined row (e.g., "Gen 1 · Matt 3 — Open in new tab") with the book icon and return arrow, same styling as the existing reference row. Tapping calls `openVerseRangeTab`.
- For single `parsedReference` with verseStart set: row label unchanged, but tapping calls `openVerseRangeTab` instead of `navigateTo`.
- For single `parsedReference` with no verse: row tapping calls `navigateTo` as today.

### performSearch() (Enter key)

Follows the same rules as above — verse range or multi-reference → `openVerseRangeTab`; whole-chapter single → `navigateTo`.

### New function

```swift
private func openVerseRangeTab(references: [BibleReference])
```

- Validates all references against `bibleStore` (book + chapter must exist); sets `errorMessage` and returns early if any fail
- Creates `NSHostingController(rootView: VerseRangeView(references: references, bibleStore: bibleStore))`
- Creates `NSWindow(contentViewController: controller)` with same size/style as host window
- Sets `tabbingMode = .preferred`, matches `tabbingIdentifier`
- Calls `host.addTabbedWindow(newWindow, ordered: .above)` and `newWindow.makeKeyAndOrderFront(nil)`
- Dismisses search after opening

### dismissSearch()

Add `parsedMultiReference = nil` to the cleanup.

---

## 4. Verse Lookup Logic

In `VerseRangeView`, for each `BibleReference`:

- Look up the book and chapter via `bibleStore.findBook(ref.book)`
- Filter chapter's verses to the range `[verseStart...verseEnd]` (inclusive); if no verse range, show all verses in the chapter
- If book or chapter not found, show a "Not found" placeholder for that section (graceful degradation)

---

## 5. Out of Scope

- Highlighting or notes in the verse range tab
- Cross-chapter verse ranges (e.g., `John 3:36 - John 4:2`) — not supported; these are rare and complex
- Keyboard navigation within the verse range tab
- Saving the verse range tab position to history or closed-tabs stack

---

## Files Changed

| File | Change |
|------|--------|
| `ESVBible/Services/ReferenceParser.swift` | Add `parseMultiple()` |
| `ESVBible/Views/VerseRangeView.swift` | New file |
| `ESVBible/ContentView.swift` | New state, updated search logic, `openVerseRangeTab()` |
