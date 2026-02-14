# Keyword Search Design

## Overview

Add keyword/text search to the existing search bar. The search bar auto-detects whether input is a Bible reference (e.g. "John 3:16") or a keyword query (e.g. "faith"). Results appear in an inline dropdown below the search bar.

## Approach: Pre-built Inverted Index

A build-time script generates an inverted index mapping normalized words to verse locations. The index is bundled as a JSON resource file and loaded lazily on first search.

### Index Structure

`Resources/search_index.json`:

```json
{
  "faith": [
    {"book": "Genesis", "chapter": 15, "verse": 6},
    {"book": "Habakkuk", "chapter": 2, "verse": 4}
  ],
  "love": [...]
}
```

Words are normalized: lowercased, punctuation stripped.

### Search Flow

1. User types in the existing search bar.
2. On each keystroke (debounced ~300ms), `ReferenceParser.parse()` is tried first.
3. If parsing fails, treat input as keyword search.
4. Scoped search: input matching `"BookName: keyword"` limits results to that book.
5. Look up words in the in-memory index.
6. For multi-word queries, intersect result sets.
7. Display up to ~50 results in an inline dropdown.

### UI: Inline Results Dropdown

- Scrollable list below the search bar (max ~300px height).
- Each row: **"Book Chapter:Verse"** + truncated verse text with keyword bolded.
- Clicking a result navigates to that chapter with the verse highlighted.
- Dismisses on Escape or clicking outside.
- Shows result count at top (e.g. "42 results for 'faith'").

### Data Loading

- New `SearchService` handles index loading and query logic.
- Index loaded lazily on first search, kept in memory.

## Files Changed/Added

- **New:** `Scripts/build_search_index.swift` - generates index from book JSONs
- **New:** `Resources/search_index.json` - the generated index
- **New:** `Services/SearchService.swift` - index loading and query logic
- **Modified:** `ContentView.swift` - search bar changes, dropdown UI
- **Modified:** `BibleStore.swift` - minor integration if needed
