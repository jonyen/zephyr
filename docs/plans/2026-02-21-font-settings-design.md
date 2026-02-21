# Font Settings + Bionic Reading — Design

**Date:** 2026-02-21
**Status:** Approved

## Overview

Add a macOS Preferences window (⌘,) with font selection and a bionic reading toggle. This is the first settings surface in Zephyr.

## Preferences Window

- SwiftUI `Settings { }` scene added to `ESVBibleApp.swift` alongside the existing `WindowGroup`
- Opens via ⌘, / Zephyr → Settings… (automatic macOS wiring)
- Single page: `AppearanceSettingsView`
- Two controls:
  - **Font picker** — segmented or inline `Picker` with three options
  - **Bionic Reading toggle** — `Toggle`
- Persistence: `@AppStorage("selectedFont")` (default `"Georgia"`) and `@AppStorage("bionicReadingEnabled")` (default `false`)

## Font Options

| Label | Font Name | Style |
|---|---|---|
| Georgia | `"Georgia"` | Serif (current default) |
| Palatino | `"Palatino"` | Serif |
| Helvetica Neue | `"Helvetica Neue"` | Sans-serif |

All three are guaranteed present on macOS. Resolved via `NSFont(name:size:)` at 16pt.

The drop-cap chapter number and verse numbers continue using system fonts — they are structural UI, not body content.

## Font Rendering Changes

- `@AppStorage` values are threaded as parameters: `ESVBibleApp` → `ContentView` → `ReadingPaneView` → `ChapterView` → `SelectableTextView`
- `SelectableTextView` replaces the current hardcoded `NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif)` with `NSFont(name: selectedFont, size: 16)`
- When font changes, `@AppStorage` triggers SwiftUI redraw → new attributed string built with new font

## Bionic Reading

- Post-processing pass on the attributed string, applied after base font and highlights
- For each word in verse text: bold the first `ceil(word.length / 2)` characters
- Bold applied via `NSFontManager.shared.convert(_:toHaveTrait: .boldFontMask)`
- Helper: `applyBionicReading(to: NSMutableAttributedString, font: NSFont)`
- Scope: verse text only — verse numbers, chapter drop-caps, and note indicators are excluded
- Works with all three font choices (independent setting)
- Toggling bionic reading triggers the same attributed string rebuild path as font changes

## Files Affected

- `ESVBibleApp.swift` — add `Settings { }` scene
- `Views/AppearanceSettingsView.swift` — new file, the preferences UI
- `Views/SelectableTextView.swift` — thread font + bionic params, update attributed string building, add bionic helper
- `ContentView.swift` — thread `@AppStorage` values down the view hierarchy
- `ReadingPaneView.swift` — thread values to `ChapterView`
