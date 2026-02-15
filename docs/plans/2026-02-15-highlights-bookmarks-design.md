# Highlights & Bookmarks Design

## Summary

Add text-level highlights (multiple colors) and chapter-level bookmarks to the Spark ESV Bible app, with visual indicators on the scrubber overlay.

## Data Models

### Highlight
```swift
enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink
}

struct Highlight: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int
    let startCharOffset: Int  // within verse text
    let endCharOffset: Int    // within verse text
    let color: HighlightColor
    let createdAt: Date
}
```

### Bookmark
```swift
struct Bookmark: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let createdAt: Date
}
```

## Persistence

Both stored as JSON files in `~/Library/Application Support/Spark/`, following the same pattern as `history.json`.

- `highlights.json`: Array of `Highlight`
- `bookmarks.json`: Array of `Bookmark`

## Service Layer: HighlightManager

`@Observable` class with:
- `highlights: [Highlight]` and `bookmarks: [Bookmark]`
- `addHighlight(book:chapter:verse:startChar:endChar:color:)`
- `removeHighlight(id:)`
- `highlights(for book:chapter:) -> [Highlight]`
- `addBookmark(book:chapter:)`
- `removeBookmark(id:)`
- `toggleBookmark(book:chapter:)`
- `isBookmarked(book:chapter:) -> Bool`
- `load()` / `save()` with atomic writes and ISO8601 date encoding

## Text Selection: SelectableTextView

SwiftUI `Text` with `.textSelection(.enabled)` doesn't expose selection ranges. Solution:

- `NSViewRepresentable` wrapping a read-only `NSTextView`
- Renders the same `NSAttributedString` as the current chapter view
- On text selection + right-click or Cmd+H, shows a popover with color options
- Maps `NSTextView` character range back to verse + character offset using known verse boundaries in the attributed string
- Popover options: yellow, green, blue, pink highlight buttons + remove highlight

## Highlight Rendering

When building `AttributedString` for a chapter in `ChapterView`:
1. Query `HighlightManager.highlights(for:chapter:)`
2. For each highlight, apply `.backgroundColor` at the computed character range
3. Search highlights (temporary, from keyword search) overlay on top with accent color
4. User highlights persist across sessions

## Bookmark UX

- `Cmd+D`: Toggle bookmark on currently visible chapter
- Menu item: Edit > Toggle Bookmark
- Visual: Small bookmark icon in chapter header when bookmarked
- History sidebar could optionally show bookmarks section

## Scrubber Integration

In `BibleScrubber`'s Canvas rendering:

### Highlight Ticks
- For each highlight, compute global chapter fraction using `BibleStore.globalChapterIndex(book:chapter:) / 1189.0`
- Draw a colored tick (3×2pt) on the **left** side of the track at the corresponding Y position
- Color matches the highlight's `HighlightColor`
- Overlapping ticks create a natural "heat map" effect

### Bookmark Markers
- For each bookmark, compute fraction the same way
- Draw a small filled diamond (4×4pt) on the **right** side of the track
- Use accent color to distinguish from highlights

### Rendering Order
1. Track background
2. Highlight ticks
3. Bookmark markers
4. Thumb (on top)

## Architecture Diagram

```
HighlightManager (@Observable)
  ├── highlights: [Highlight]  →  highlights.json
  └── bookmarks: [Bookmark]    →  bookmarks.json

ChapterView
  └── SelectableTextView (NSViewRepresentable)
       ├── NSTextView (read-only, attributed string)
       ├── Selection → highlight popover
       └── Reads HighlightManager for background colors

BibleScrubber (Canvas)
  ├── Track + Thumb (existing)
  ├── Highlight ticks (colored, left of track)
  └── Bookmark diamonds (accent, right of track)

ContentView
  ├── Cmd+D → toggleBookmark
  └── Passes HighlightManager to child views
```
