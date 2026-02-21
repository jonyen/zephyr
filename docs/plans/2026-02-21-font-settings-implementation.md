# Font Settings + Bionic Reading Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a macOS Preferences window (⌘,) with font selection (Georgia, Palatino, Helvetica Neue) and a bionic reading toggle that applies to all Bible verse text.

**Architecture:** A new SwiftUI `Settings` scene hosts `AppearanceSettingsView`. Two `@AppStorage` keys (`selectedFont`, `bionicReadingEnabled`) propagate changes reactively. `ChapterView` reads both keys directly and passes them to `SelectableTextView`, which resolves the font and applies a bionic reading post-pass to the attributed string.

**Tech Stack:** SwiftUI `Settings` scene, `@AppStorage`, `NSFont`, `NSFontManager`, `NSMutableAttributedString`, `NSString.enumerateSubstrings(in:options:using:)`

---

### Task 1: Create `AppearanceSettingsView.swift`

**Files:**
- Create: `ESVBible/Views/AppearanceSettingsView.swift`

**Step 1: Create the file**

```swift
import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false

    var body: some View {
        Form {
            Section("Font") {
                Picker("Font", selection: $selectedFont) {
                    Text("Georgia")
                        .font(.custom("Georgia", size: 14))
                        .tag("Georgia")
                    Text("Palatino")
                        .font(.custom("Palatino-Roman", size: 14))
                        .tag("Palatino-Roman")
                    Text("Helvetica Neue")
                        .font(.custom("HelveticaNeue", size: 14))
                        .tag("HelveticaNeue")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Reading") {
                Toggle("Bionic Reading", isOn: $bionicReadingEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .padding(.vertical, 8)
    }
}
```

**Step 2: Verify the file compiles**

Build the project (⌘B). Expected: builds cleanly (the view isn't wired yet, so it won't appear in the app).

**Step 3: Commit**

```bash
git add ESVBible/Views/AppearanceSettingsView.swift
git commit -m "feat: add AppearanceSettingsView with font picker and bionic toggle"
```

---

### Task 2: Wire up the `Settings` scene

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift:54-58`

**Step 1: Add the `Settings` scene**

In `ESVBibleApp.swift`, after the closing `}` of the `WindowGroup` block (after line 158, before the closing `}` of `var body: some Scene`), add:

```swift
        Settings {
            AppearanceSettingsView()
        }
```

The `body` property should look like:

```swift
var body: some Scene {
    WindowGroup(for: ChapterPosition.self) { $position in
        ContentView(initialPosition: position)
    }
    .defaultSize(width: 800, height: 600)
    .commands {
        // ... existing commands unchanged ...
    }

    Settings {
        AppearanceSettingsView()
    }
}
```

**Step 2: Build and manually verify**

Build and run. Press ⌘, (or Zephyr → Settings…). Expected: a small preferences window appears with a font radio group and a bionic reading toggle.

**Step 3: Commit**

```bash
git add ESVBible/ESVBibleApp.swift
git commit -m "feat: wire Settings scene for Preferences window"
```

---

### Task 3: Add font + bionic parameters to `SelectableTextView`

**Files:**
- Modify: `ESVBible/Views/SelectableTextView.swift`

**Context:** `SelectableTextView` is an `NSViewRepresentable`. Currently `buildAttributedString` resolves the body font with a hardcoded system serif descriptor (line 132). We'll replace this with the user-selected font and add a bionic reading post-pass.

**Step 1: Add the two new properties to `SelectableTextView`**

At the end of the existing property list (after `let onEditNote: (Note) -> Void` on line 18), add:

```swift
    let selectedFont: String
    let bionicReadingEnabled: Bool
```

**Step 2: Update font resolution in `updateNSView`**

In `updateNSView`, the drop-cap height is calculated from `bodyFont` metrics. Replace lines 70–77:

```swift
        let serifDescriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
        let bodyFont = NSFont(descriptor: serifDescriptor, size: 16) ?? NSFont.systemFont(ofSize: 16)
        let lineHeight = bodyFont.ascender + abs(bodyFont.descender) + bodyFont.leading
        let twoLineHeight = lineHeight * 2 + 6 // 6 = paragraphStyle.lineSpacing

        let computedFontSize = twoLineHeight

        let dropCapFont = NSFont(descriptor: serifDescriptor, size: computedFontSize) ?? NSFont.systemFont(ofSize: computedFontSize)
```

With:

```swift
        let bodyFont = NSFont(name: selectedFont, size: 16) ?? NSFont.systemFont(ofSize: 16)
        let lineHeight = bodyFont.ascender + abs(bodyFont.descender) + bodyFont.leading
        let twoLineHeight = lineHeight * 2 + 6 // 6 = paragraphStyle.lineSpacing

        let computedFontSize = twoLineHeight

        let serifDescriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
        let dropCapFont = NSFont(descriptor: serifDescriptor, size: computedFontSize) ?? NSFont.systemFont(ofSize: computedFontSize)
```

Note: the drop-cap face stays as system serif (for visual consistency), but its *size* is now computed from the selected body font's metrics.

**Step 3: Update font resolution in `buildAttributedString`**

Replace line 132:

```swift
        let bodyFont = NSFont(descriptor: NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body), size: 16) ?? NSFont.systemFont(ofSize: 16)
```

With:

```swift
        let bodyFont = NSFont(name: selectedFont, size: 16) ?? NSFont.systemFont(ofSize: 16)
```

**Step 4: Add the `applyBionicReading` helper**

Add this private method inside the `SelectableTextView` struct, after `isSearchHighlight`:

```swift
    private func applyBionicReading(to attrStr: NSMutableAttributedString, font: NSFont) {
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let nsString = attrStr.string as NSString
        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: .byWords
        ) { _, wordRange, _, _ in
            let boldLength = max(1, Int(ceil(Double(wordRange.length) / 2.0)))
            let boldRange = NSRange(location: wordRange.location, length: boldLength)
            attrStr.addAttribute(.font, value: boldFont, range: boldRange)
        }
    }
```

**Step 5: Call `applyBionicReading` in `buildAttributedString`**

Inside `buildAttributedString`, the loop builds `textStr` for each verse. After the highlights loop and just before `result.append(textStr)`, add the bionic pass:

```swift
            // Apply bionic reading if enabled
            if bionicReadingEnabled {
                applyBionicReading(to: textStr, font: bodyFont)
            }

            result.append(textStr)
```

The full loop ending should look like:

```swift
            // Apply user highlights for this verse
            let verseHighlights = highlights.filter { $0.verse == verse.number }
            for h in verseHighlights {
                let start = max(0, h.startCharOffset)
                let end = min(verse.text.count, h.endCharOffset)
                if start < end {
                    textStr.addAttribute(.backgroundColor, value: h.color.nsColor, range: NSRange(location: start, length: end - start))
                }
            }

            // Apply bionic reading if enabled
            if bionicReadingEnabled {
                applyBionicReading(to: textStr, font: bodyFont)
            }

            result.append(textStr)
```

**Step 6: Build and verify compilation**

Build (⌘B). Expected: compile error in `ChapterView` because `SelectableTextView` now requires two new parameters. That's expected — we fix it in Task 4.

**Step 7: Commit will happen after Task 4 (since it won't build yet)**

---

### Task 4: Thread parameters through `ChapterView`

**Files:**
- Modify: `ESVBible/ReadingPaneView.swift:197-323`

**Context:** `ChapterView` is a `private struct` at the bottom of `ReadingPaneView.swift`. It creates `SelectableTextView` and needs to pass the two new parameters. Since `ChapterView` is a SwiftUI view, it can read `@AppStorage` directly without threading through `ReadingPaneView`.

**Step 1: Add `@AppStorage` properties to `ChapterView`**

Inside `private struct ChapterView: View`, after the existing `@State private var dropCapFontSize: CGFloat = 42` declaration (line 211), add:

```swift
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false
```

**Step 2: Pass the new params to `SelectableTextView`**

In the `SelectableTextView(...)` call within `ChapterView.body` (around line 223), add the two new arguments after the existing `onEditNote:` argument and before the closing `)`:

```swift
                onEditNote: { note in
                    notePopoverVerseStart = note.verseStart
                    notePopoverVerseEnd = note.verseEnd
                    editingNote = note
                    showNotePopover = true
                },
                selectedFont: selectedFont,
                bionicReadingEnabled: bionicReadingEnabled
```

**Step 3: Build**

Build (⌘B). Expected: clean build, no errors.

**Step 4: Commit both Task 3 and Task 4 together**

```bash
git add ESVBible/Views/SelectableTextView.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: implement font selection and bionic reading in SelectableTextView"
```

---

### Task 5: Manual end-to-end verification

**Step 1: Run the app**

Launch Zephyr. Navigate to any passage.

**Step 2: Verify font switching**

Open Settings (⌘,). Switch to Palatino. Verify Bible text changes to Palatino immediately. Switch to Helvetica Neue. Verify text changes to the sans-serif font. Switch back to Georgia. Verify default is restored.

Expected: text reflows correctly, drop-cap still spans two lines, verse numbers unchanged.

**Step 3: Verify bionic reading**

Enable the Bionic Reading toggle. Verify the first ~half of each word in verse text becomes bold. Disable it. Verify text returns to normal weight.

**Step 4: Verify combinations**

Try Palatino + bionic reading, Helvetica Neue + bionic reading. Both should work independently.

**Step 5: Verify persistence**

Quit and relaunch the app. Verify the previously selected font and bionic setting are restored.

**Step 6: Commit verification note**

```bash
git commit --allow-empty -m "chore: verify font settings and bionic reading end-to-end"
```

---

### Summary of files changed

| File | Action |
|------|--------|
| `ESVBible/Views/AppearanceSettingsView.swift` | Create |
| `ESVBible/ESVBibleApp.swift` | Add `Settings` scene |
| `ESVBible/Views/SelectableTextView.swift` | Add params, update font, add bionic helper |
| `ESVBible/ReadingPaneView.swift` | Add `@AppStorage` to `ChapterView`, pass params |
