# Reading Themes Design

**Date:** 2026-02-21

## Goal

Add five reading themes to Zephyr — System, Light, Dark, Sepia, Black — selectable in Settings. The theme applies to the entire app window including the reading pane, sidebars, and overlays.

## Data Model

A `ReadingTheme` enum stored in `@AppStorage("readingTheme")` as its `rawValue` (default: `"system"`).

```swift
enum ReadingTheme: String, CaseIterable {
    case system, light, dark, sepia, black
}
```

Each case exposes:

| Property | Type | Purpose |
|----------|------|---------|
| `colorScheme` | `ColorScheme?` | Passed to `.preferredColorScheme()`. `nil` = follow OS. |
| `backgroundColor` | `Color` | SwiftUI window background fill. |
| `nsTextColor` | `NSColor` | Primary text in `NSTextView` attributed strings. |
| `nsSecondaryColor` | `NSColor` | Verse numbers, secondary labels in `NSTextView`. |

### Color values

| Theme | colorScheme | backgroundColor | nsTextColor | nsSecondaryColor |
|-------|-------------|-----------------|-------------|------------------|
| System | `nil` | `.clear` (adaptive) | `NSColor.labelColor` | `NSColor.secondaryLabelColor` |
| Light | `.light` | `.white` | `NSColor.labelColor` | `NSColor.secondaryLabelColor` |
| Dark | `.dark` | adaptive dark | `NSColor.labelColor` | `NSColor.secondaryLabelColor` |
| Sepia | `.light` | `#F4ECD8` | `#3B2A1A` | `#7B6348` |
| Black | `.dark` | `#000000` | `#CCCCCC` | `#888888` |

System, Light, and Dark use `NSColor.labelColor` / `NSColor.secondaryLabelColor` (adaptive) so text color resolves correctly for the forced appearance. Sepia and Black use fixed colors since no system appearance produces those palettes.

## Settings UI

Add an "Appearance" section at the top of `AppearanceSettingsView`, above the existing Font section. Use a `Picker` with `.radioGroup` style (consistent with the font picker). Each row shows the theme name with a small filled `Circle` swatch in the theme's background color, outlined in its text color.

```
┌─ Appearance ──────────────────────┐
│  ○ ● System                       │
│  ○ ● Light                        │
│  ○ ● Dark                         │
│  ● ● Sepia                        │
│  ○ ● Black                        │
└───────────────────────────────────┘
┌─ Font ────────────────────────────┐
│  ...existing...                   │
└───────────────────────────────────┘
┌─ Reading ─────────────────────────┐
│  ...existing...                   │
└───────────────────────────────────┘
```

## Application Points

### `ContentView`
- Read `@AppStorage("readingTheme")` as a `ReadingTheme`.
- Apply to `mainContent`:
  - `.preferredColorScheme(theme.colorScheme)` — switches OS appearance for the whole window.
  - `.background(theme.backgroundColor.ignoresSafeArea())` — fills the window background for Sepia/Black.

### `SelectableTextView`
- Add `theme: ReadingTheme` parameter.
- In `buildAttributedString`, replace:
  - `NSColor.labelColor` → `theme.nsTextColor`
  - `NSColor.secondaryLabelColor` → `theme.nsSecondaryColor`

### Threading
`ContentView` → `ReadingPaneView` → `ChapterView` → `SelectableTextView`. Each passes `theme` as a plain value parameter. No observable or environment key needed.

## What Does Not Change

- `.regularMaterial` overlays (search, TOC, keyboard shortcuts) — adapt automatically via `preferredColorScheme`.
- Red-letter text (`NSColor.systemRed`) — intentional, stays as-is.
- User highlight colors — intentional, stays as-is.
- `BibleScrubber` — uses semantic SwiftUI colors, self-adapts.

## Files Changed

| File | Change |
|------|--------|
| `ESVBible/Models/ReadingTheme.swift` | New — enum + color definitions |
| `ESVBible/Views/AppearanceSettingsView.swift` | Add Appearance section |
| `ESVBible/ContentView.swift` | Read theme, apply `.preferredColorScheme` + `.background` |
| `ESVBible/ReadingPaneView.swift` | Pass `theme` to `ChapterView` |
| `ESVBible/Views/SelectableTextView.swift` | Accept `theme`, use `theme.nsTextColor` / `theme.nsSecondaryColor` |
| `ESVBible/Views/ChapterView.swift` (or wherever defined) | Pass `theme` to `SelectableTextView` |
