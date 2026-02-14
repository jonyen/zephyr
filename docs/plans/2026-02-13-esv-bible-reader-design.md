# ESV Bible Reader for macOS — Design

## Overview

A lightweight, native macOS app for reading the ESV Bible. Built with SwiftUI. Bible text is downloaded once via the ESV API and stored locally as JSON for offline reading.

## Data Layer

- **Download script**: A Swift command-line tool that calls the ESV API (`v3/passage/text`) for each chapter of all 66 books and saves the result as `bible.json`.
- **Structure**: `[Book] → [Chapter] → [Verse] → text` — a single JSON file (~5MB).
- **Models**: `Book`, `Chapter`, `Verse` as `Codable` structs. A `BibleStore` class loads JSON at startup and provides lookup by reference.
- **Bundle**: The JSON file is placed in the app bundle as a resource.

## UI Layout

```
┌─────────────────────────────────────────────┐
│  ┌─────────────────────────────────┐  [☰]  │
│  │  Search: "John 3:16"           │        │
│  └─────────────────────────────────┘        │
├────────────┬────────────────────────────────┤
│  HISTORY   │                                │
│            │   John 3                       │
│  John 3:16 │                                │
│  Gen 1     │   ¹ For God so loved...        │
│  Rom 8:28  │                                │
│  Ps 23     │   (full chapter, scrollable,   │
│            │    target verse highlighted)   │
├────────────┴────────────────────────────────┤
│  ◀ Previous Chapter    Next Chapter ▶       │
└─────────────────────────────────────────────┘
```

- **Search bar** at top — parses references like "John 3:16", "Gen 1", "1 Cor 13:4-7".
- **History sidebar** — collapsible, last ~100 lookups, click to revisit.
- **Reading pane** — full chapter with superscript verse numbers, target verse highlighted.
- **Chapter navigation** — prev/next buttons at the bottom.

## Search & Navigation

Reference parser handles:
- `Book Chapter:Verse` (e.g., John 3:16)
- `Book Chapter:Start-End` (e.g., Romans 8:28-30)
- `Book Chapter` (e.g., Genesis 1)
- Common abbreviations (Gen, Ex, Lev, Ps, Matt, etc.)

On search: load the full chapter, scroll to target verse, add history entry.

## History Persistence

- Stored as JSON array in `~/Library/Application Support/ESVBible/history.json`.
- Each entry: `{ reference, timestamp }`.
- Capped at 100 entries, newest first.
- Persisted on every new lookup.

## Window Behavior

- Default: 800x600. Minimum: 400x500.
- Full screen via native macOS support.
- Sidebar collapses at narrow widths.

## Visual Style

- System font (SF Pro), larger body text for readability.
- Light/dark mode follows system.
- Verse numbers as subtle superscripts.
- Highlighted verse: soft background accent.
- Minimal chrome — just the search bar and sidebar.

## Tech Stack

- SwiftUI, macOS 14+
- Swift Package Manager for project structure
- No external dependencies
