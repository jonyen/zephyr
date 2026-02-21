# Reading Themes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add five reading themes (System, Light, Dark, Sepia, Black) selectable in Settings, applied to the entire app window.

**Architecture:** A `ReadingTheme` enum stored in `@AppStorage("readingTheme")` drives two mechanisms: SwiftUI's `.preferredColorScheme()` for Light/Dark/System, and custom `NSColor` values injected into `SelectableTextView`'s attributed string builder for Sepia/Black. `ChapterView` (private struct inside `ReadingPaneView.swift`) reads the theme via `@AppStorage` directly — same pattern already used for `selectedFont` and `bionicReadingEnabled` — so no parameter threading through `ReadingPaneView` is needed.

**Tech Stack:** SwiftUI (`@AppStorage`, `.preferredColorScheme`, `Color`), AppKit (`NSColor`, `NSTextView` attributed strings), Xcode

---

### Task 1: Create `ReadingTheme.swift`

**Files:**
- Create: `ESVBible/Models/ReadingTheme.swift`

**Step 1: Create the file**

Create `ESVBible/Models/ReadingTheme.swift` with this exact content:

```swift
import SwiftUI
import AppKit

enum ReadingTheme: String, CaseIterable {
    case system
    case light
    case dark
    case sepia
    case black

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .sepia:  return "Sepia"
        case .black:  return "Black"
        }
    }

    /// Passed to `.preferredColorScheme()`. nil = follow the OS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:         return nil
        case .light:          return .light
        case .dark:           return .dark
        case .sepia:          return .light
        case .black:          return .dark
        }
    }

    /// SwiftUI background fill. Clear for system/light/dark (OS handles it).
    var backgroundColor: Color {
        switch self {
        case .system: return .clear
        case .light:  return .white
        case .dark:   return .clear
        case .sepia:  return Color(red: 0.957, green: 0.925, blue: 0.847) // #F4ECD8
        case .black:  return .black
        }
    }

    /// Primary text color for NSTextView attributed strings.
    var nsTextColor: NSColor {
        switch self {
        case .system, .light, .dark:
            return .labelColor           // adaptive — resolves correctly for forced appearance
        case .sepia:
            return NSColor(red: 0.231, green: 0.165, blue: 0.102, alpha: 1) // #3B2A1A
        case .black:
            return NSColor(white: 0.8, alpha: 1) // #CCCCCC
        }
    }

    /// Secondary text color used for verse numbers.
    var nsSecondaryColor: NSColor {
        switch self {
        case .system, .light, .dark:
            return .secondaryLabelColor  // adaptive
        case .sepia:
            return NSColor(red: 0.482, green: 0.388, blue: 0.282, alpha: 1) // #7B6348
        case .black:
            return NSColor(white: 0.533, alpha: 1) // #888888
        }
    }

    /// Fill color for the small swatch circle in the settings picker.
    var swatchFill: Color {
        switch self {
        case .system: return Color(NSColor.windowBackgroundColor)
        case .light:  return .white
        case .dark:   return Color(NSColor(white: 0.2, alpha: 1))
        case .sepia:  return Color(red: 0.957, green: 0.925, blue: 0.847)
        case .black:  return .black
        }
    }

    /// Border color for the swatch circle.
    var swatchBorder: Color {
        switch self {
        case .system, .light: return .black.opacity(0.25)
        case .dark:           return .white.opacity(0.25)
        case .sepia:          return Color(red: 0.231, green: 0.165, blue: 0.102).opacity(0.5)
        case .black:          return .white.opacity(0.2)
        }
    }
}
```

**Step 2: Build to verify it compiles**

In Xcode: Product → Build (⌘B), or:
```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add ESVBible/Models/ReadingTheme.swift
git commit -m "feat: add ReadingTheme enum with color values for all five themes"
```

---

### Task 2: Thread theme into `SelectableTextView` and `ChapterView`

Both of these are in `ReadingPaneView.swift` — `ChapterView` is a private struct defined at line 197.

**Files:**
- Modify: `ESVBible/Views/SelectableTextView.swift` (add `theme` parameter, update `buildAttributedString`)
- Modify: `ESVBible/ReadingPaneView.swift` (update `ChapterView`)

**Step 1: Add `theme` parameter to `SelectableTextView`**

In `SelectableTextView.swift`, the stored property list currently ends with:
```swift
    let selectedFont: String
    let bionicReadingEnabled: Bool
```

Add `theme` after `bionicReadingEnabled`:
```swift
    let selectedFont: String
    let bionicReadingEnabled: Bool
    let theme: ReadingTheme
```

**Step 2: Update `buildAttributedString` to use theme colors**

In `buildAttributedString`, there are two occurrences of `NSColor.secondaryLabelColor` and two of `NSColor.labelColor`. Replace them:

Find (verse number attributes, line ~143):
```swift
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: verseNumFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .baselineOffset: 6,
                    .paragraphStyle: paragraphStyle
                ]
```
Replace with:
```swift
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: verseNumFont,
                    .foregroundColor: theme.nsSecondaryColor,
                    .baselineOffset: 6,
                    .paragraphStyle: paragraphStyle
                ]
```

Find (plain verse text, line ~183):
```swift
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: NSColor.labelColor
                ]
                textStr = NSMutableAttributedString(string: verse.text + " ", attributes: attrs)
```
Replace with:
```swift
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: theme.nsTextColor
                ]
                textStr = NSMutableAttributedString(string: verse.text + " ", attributes: attrs)
```

Find (the `defaultAttrs` in `buildRedLetterAttributedString`, line ~217):
```swift
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor
        ]
```
Replace with:
```swift
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: theme.nsTextColor
        ]
```

Note: `buildRedLetterAttributedString` is a private method so it doesn't receive `theme` as a parameter — add it as a parameter to match the call site:

Find the method signature:
```swift
    private func buildRedLetterAttributedString(text: String, font: NSFont, paragraphStyle: NSParagraphStyle) -> NSMutableAttributedString {
```
Replace with:
```swift
    private func buildRedLetterAttributedString(text: String, font: NSFont, paragraphStyle: NSParagraphStyle, theme: ReadingTheme) -> NSMutableAttributedString {
```

Find the call site in `buildAttributedString` (~line 179):
```swift
                textStr = buildRedLetterAttributedString(
                    text: verse.text, font: bodyFont, paragraphStyle: paragraphStyle
                )
```
Replace with:
```swift
                textStr = buildRedLetterAttributedString(
                    text: verse.text, font: bodyFont, paragraphStyle: paragraphStyle, theme: theme
                )
```

**Step 3: Update `ChapterView` to read and pass theme**

In `ReadingPaneView.swift`, inside `ChapterView`, find the existing `@AppStorage` declarations (~line 212):
```swift
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false
```
Add theme below them:
```swift
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false
    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
```

Find the `SelectableTextView(...)` call in `ChapterView.body`. It currently ends with:
```swift
                selectedFont: selectedFont,
                bionicReadingEnabled: bionicReadingEnabled
```
Add `theme`:
```swift
                selectedFont: selectedFont,
                bionicReadingEnabled: bionicReadingEnabled,
                theme: readingTheme
```

**Step 4: Build to verify**

```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: pass ReadingTheme into SelectableTextView for themed text colors"
```

---

### Task 3: Apply theme to `ContentView`

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add `@AppStorage` for theme**

In `ContentView`, near the other `@AppStorage` declarations (~line 21), add:
```swift
    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
```

**Step 2: Apply theme modifiers in `body`**

`body` currently reads:
```swift
    var body: some View {
        mainContent
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousBookmark)) { _ in
```

Add the two theme modifiers immediately after `mainContent`, before the first `.onReceive`:
```swift
    var body: some View {
        mainContent
        .preferredColorScheme(readingTheme.colorScheme)
        .background(readingTheme.backgroundColor.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousBookmark)) { _ in
```

**Step 3: Build and smoke-test**

Build succeeds, then run the app. Open Settings (⌘,) — the Appearance section isn't there yet (added next task), so the theme stays at `.system`. Verify the app looks identical to before.

```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

**Step 4: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: apply ReadingTheme preferredColorScheme and background to ContentView"
```

---

### Task 4: Add Appearance picker to Settings

**Files:**
- Modify: `ESVBible/Views/AppearanceSettingsView.swift`

**Step 1: Add `@AppStorage` for theme**

Add at the top of `AppearanceSettingsView`, alongside the existing storage:
```swift
    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
```

**Step 2: Add Appearance section**

The `Form` body currently starts with `Section("Font") {`. Add the Appearance section before it:

```swift
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $readingTheme) {
                    ForEach(ReadingTheme.allCases, id: \.self) { theme in
                        Label {
                            Text(theme.displayName)
                        } icon: {
                            Circle()
                                .fill(theme.swatchFill)
                                .overlay(Circle().strokeBorder(theme.swatchBorder, lineWidth: 1))
                                .frame(width: 12, height: 12)
                        }
                        .tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }

            Section("Font") {
                // ... existing font picker, unchanged
```

**Step 3: Build, run, and verify all five themes**

```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' build 2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Launch the app and open Settings (⌘,). Verify:
- All five theme options appear with color swatches
- Selecting **Light** → app switches to light appearance
- Selecting **Dark** → app switches to dark appearance
- Selecting **Sepia** → warm tan background, dark brown text
- Selecting **Black** → pure black background, light grey text
- Selecting **System** → follows macOS system appearance
- Theme persists after quitting and relaunching

**Step 4: Commit**

```bash
git add ESVBible/Views/AppearanceSettingsView.swift
git commit -m "feat: add Appearance theme picker to Settings with five reading themes"
```
