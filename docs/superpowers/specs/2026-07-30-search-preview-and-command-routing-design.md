# Search Previews and Tab Command Routing

Date: 2026-07-30

Three related changes to the search overlay and to how window-scoped commands reach tabs.

## 1. Verse preview in search results

Searching a reference shows only the reference itself, so there is no way to confirm you typed
the one you meant without opening it.

`BibleStore` gains:

```swift
func previewText(for reference: BibleReference) -> String?
```

It returns the text of the first verse the reference points at — `verseStart` when given,
otherwise verse 1 of `reference.chapter`. It skips forward past empty verses: the ESV omits a
handful (Mark 9:44, Acts 8:37) as later manuscript additions, and those would otherwise preview
as a blank line. Returns `nil` when the book or chapter is missing, or when no non-empty verse
follows the start verse.

In `searchResultsList`, the parsed-reference rows become a `VStack`: the existing reference line,
plus the preview beneath it in `.caption` / secondary with `lineLimit(2)`. That is the treatment
keyword results already use, so the dropdown reads as one list. Multi-reference rows preview the
first reference.

Tests cover single verse, bare chapter, verse range, missing chapter, and the empty-verse skip.

## 2. Dropdown sizes to content

`ScrollView` is greedy, so a single result still paints a full 300pt box. Applying
`.fixedSize(horizontal: false, vertical: true)` before `.frame(maxHeight: 300)` makes it adopt its
content height and clamp at 300, scrolling beyond that.

## 3. Command routing

Window-scoped commands were posted with `object: nil`, so every tab acted on them — toggling
history opened it in all of them. The commands that *were* window-targeted could only be answered
by a `ContentView`, so they died silently whenever a verse-range tab was frontmost.

**The rule:** every menu command posts `object: NSApp.keyWindow`, and each `ContentView` handler
guards on `hostWindow`.

Affected: `.showSearch`, `.showTableOfContents`, `.toggleHistory`, `.toggleNotes`,
`.toggleBookmark`, `.navigatePreviousBookmark`, `.navigateNextBookmark`, `.navigateToReference`,
and the page-scroll events from the local key monitor.

### Verse-range tabs

`TabCoordinator.Entry` gains a kind — `.reader` or `.verseRange`. `ContentView` registers as
`.reader`; `openVerseRangeTab` registers `.verseRange`.

A reader command arriving at a verse card opens a reader tab at that card's chapter and runs
there. The coordinator stashes the pending command against the new window; that `ContentView`
drains it once it appears.

### Carve-outs

- **Keep Window on Top** moves out of `ContentView` into the menu action — it is pure
  `NSWindow.level` and needs no view, so it starts working in verse tabs. This also fixes the
  current bug where every tab toggles its own copy of the state.
- **Keyboard Shortcuts (⌘/)** targets the key window and is a no-op in a verse card. Spawning a
  tab to show a help overlay would be absurd.
- **Check for Updates** keeps broadcasting. It is app-level rather than a tab bug, and rerouting
  it would drag `UpdateService` ownership into scope.
