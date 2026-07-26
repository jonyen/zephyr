# Zephyr Web — Fresh Rebuild Design

**Date:** 2026-07-23
**Status:** Approved

## Context

Zephyr is a native macOS ESV Bible reader (`~/Projects/Zephyr`, SwiftUI). A previous
web port (this repo's Next.js + Prisma + JWT-auth history) missed the mark in two
ways: the look & feel didn't match the native app, and the scrubber and reading
flow were buggy. This design replaces that attempt with a fresh build.

Decisions made during brainstorming:

- **Start fresh**, replacing the contents of `~/Projects/zephyr-web` (old attempt
  remains in git history).
- **Local-only user data** — no accounts, no backend, no database. Matches the
  native app's "no accounts, no tracking" ethos.
- **V1 scope:** reading view, book/chapter navigation, scrubber, search
  (reference + keyword), highlights/bookmarks/history, themes & typography.
  Notes and tabs are explicitly deferred.
- **Stack:** Vite + React + TypeScript SPA.
- **Hosting:** `jonyen.com/zephyr` (GitHub Pages user site) until a permanent
  home is chosen.
- Extra care on the two prior pain points: **scrubber behavior** and
  **scrolling/reading flow**.

## 1. Architecture & Data

**Stack:** Vite + React + TypeScript single-page app. No server code. React
Router with `basename` derived from Vite's `base` (`/zephyr/` in production
builds, `/` in dev). URL scheme: `/:book/:chapter` (e.g. `/isaiah/40`), book
slugs lowercase (`1-corinthians`, `song-of-solomon`).

**Bible data:** The 66 per-book ESV JSON files and `red_letter_verses.json`
carry over from the previous attempt into `public/data/`. Shape:
`{ name, chapters: [{ number, verses: [{ number, text }] }] }`. Verse text
embeds `\n` and leading 4-space indents for poetry lines.

- Books are fetched lazily on first use and cached in a memory map.
- A generated `src/lib/bible-index.ts` (built by a small script from the JSONs,
  committed) holds book names, slugs, chapter counts, and global chapter index
  math (0–1188), mirroring the native `BibleStore`. Navigation, the scrubber,
  and reference parsing never require a network fetch.

**User data (localStorage, versioned keys):**

| Key | Contents |
|---|---|
| `zephyr.v1.highlights` | `{book, chapter, verse, startChar, endChar, color}[]` |
| `zephyr.v1.bookmarks` | `{book, chapter}[]` |
| `zephyr.v1.history` | `{book, chapter, timestamp}[]` (capped, most recent first) |
| `zephyr.v1.prefs` | theme, font, red-letter toggle, bionic toggle |

A thin storage module wraps reads/writes with JSON parse/validate; corrupted or
missing keys fall back to defaults rather than crashing.

**Search:** No prebuilt search index (the old 25MB `search_index.json` is
dropped). Reference parsing is pure client-side logic. Keyword search fetches
any not-yet-loaded book JSONs on first search (~4.5MB total, then cached) and
scans verses in memory.

## 2. Reading Flow

Mirrors the native `ReadingPaneView` model: a flat ordered list of loaded
chapters, initially just the navigation target.

- **Append/prepend:** sentinel elements near the list edges (IntersectionObserver)
  trigger loading the next/previous chapter, crossing book boundaries exactly as
  the native `chapterAfter`/`chapterBefore` do.
- **Prepend without scroll jump:** the scroller has `overflow-anchor: none`; on
  prepend, a `useLayoutEffect` measures the height delta and adjusts `scrollTop`
  synchronously in the same frame. This is the core fix for the prior jank.
- **Bounded DOM:** loaded chapters capped at ~12; the far end is trimmed with
  the same scroll-compensation technique so long sessions stay smooth.
- **Position tracking:** IntersectionObserver on chapter boundaries determines
  the topmost visible chapter, which drives the URL (`history.replaceState` — no
  history spam), the scrubber thumb, and debounced reading-history logging.
- **Navigation** (scrubber, search, TOC, history, arrow keys) resets the list to
  the target chapter and scrolls to top (native `navigationID` reset). Search
  navigation additionally scrolls to and briefly highlights the target verse.

**Chapter rendering:**

- Book title (large, bold) above chapter 1 of each book.
- Drop-cap chapter number (~42px serif) beside the first lines; bookmark flag
  shown next to it when the chapter is bookmarked.
- Verses joined with spaces into flowing paragraphs; Proverbs joins with
  newlines (one verse per line) as the native renderer does.
- Poetry: embedded `\n`/indent structure rendered with `white-space: pre-wrap`
  and a hanging indent so wrapped lines stay aligned.
- Superscript verse numbers; red-letter words in red (toggleable); optional
  bionic reading (bold leading letters).
- Content column max-width 700px, centered; divider between chapters.

## 3. Scrubber

A direct port of the native `BibleScrubber`:

- **Strip:** fixed 30px-wide hover/drag zone at the right edge, full height.
  SVG rendering: 2px rounded track (20px top/bottom inset), 6×30px rounded
  accent thumb. Thumb fraction = global chapter index / 1188; while dragging,
  the drag fraction drives the thumb directly.
- **Markers:** highlight ticks (6×3px, highlight color) left of the track;
  bookmark diamonds (6×6px, accent) right of the track.
- **Dragging:** Pointer Events with `setPointerCapture` on the strip. Drag Y →
  clamped fraction → rounded global chapter index; **navigate only when the
  resolved index changes** (`lastNavigatedIndex` guard, as in native).
- **Label panel:** shown while hovering the strip, dragging, or hovering the
  panel itself; hides after a 150ms delay (cancelled on re-enter); 200ms fade
  in/out. An absolutely positioned layer to the left of the strip containing all
  66 book names at 13px:
  - Positions from the ported min-gap spacing algorithm: start at each book's
    chapter-range midpoint fraction, forward pass pushes overlapping labels down,
    backward pass pushes back up, 20px minimum gap.
  - Current book semibold; other labels fade with distance from it (0.07/step,
    floor 0.3). Hovered row gets a capsule background and full opacity.
  - Click on a book name navigates to its chapter 1.
  - The panel is translated vertically so the focused book's label aligns with
    the thumb position.
- **Wheel:** wheel events over the strip/panel step the focused book up/down,
  previewing in the panel without navigating.

## 4. Features

- **Search overlay** (`⌘K` or `/`): single input. Reference queries
  ("john 3:16", "1 cor 13", "ps 23") parse → navigate, briefly highlighting the
  verse range. Other queries run keyword search; results list shows reference +
  snippet with match emphasized; Enter/click navigates.
- **Selection toolbar:** selecting verse text pops a small floating toolbar with
  highlight colors and remove-highlight. Highlights store verse + char range
  (native model) and render as background spans across re-renders.
- **Bookmarks:** `⌘D` toggles the current chapter; flag by the drop-cap;
  diamond on the scrubber.
- **TOC overlay** (`t`): 66-book grid, then chapter-number grid for the chosen
  book.
- **History:** logged automatically (debounced) on chapter change; overlay
  lists recent locations; click to return.
- **Themes & typography:** System/Light/Dark/Sepia/Black themes via CSS
  variables on a `data-theme` root attribute; fonts Georgia (default),
  Palatino, Helvetica Neue; red-letter and bionic toggles. Controlled from a
  quiet settings popover.
- **Keyboard shortcuts:** `←/→` previous/next chapter, `⌘K`//` search, `t`
  TOC, `⌘D` bookmark, `?` shortcuts overlay.

## 5. Deployment

- Vite `base: '/zephyr/'` for production builds.
- GitHub Actions workflow builds on push to `main` and publishes `dist/` into
  the `jonyen.github.io` repo under `/zephyr/` (deploy key or PAT configured
  once). A `404.html` copy of `index.html` makes deep links work on Pages.
- Moving to a permanent home later only changes `base` and the publish target.
- ESV copyright/attribution line included in the UI (public web distribution
  makes this necessary).

## 6. Error Handling

- Book fetch failure: inline retry UI in the reading pane (offline/networks).
- Unknown book slug or out-of-range chapter in URL: redirect to Genesis 1.
- localStorage full/corrupted: fall back to defaults; never block reading.

## 7. Testing

- **Vitest unit tests (TDD):** reference parser, bible-index/global chapter
  math, label-spacing algorithm, highlight char-range application, storage
  module fallbacks.
- **Manual verification:** scrubber feel and scroll behavior compared
  side-by-side with the native app; browser check on Safari + Chrome.

## Explicitly Out of Scope (v1)

- Notes (native has them; deferred to keep v1 focused)
- Tabbed browsing
- Service worker / offline install (PWA) — candidate for v2
- Accounts or cross-device sync
