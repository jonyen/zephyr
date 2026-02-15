# Highlights & Bookmarks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add text-level highlights (multiple colors) and chapter-level bookmarks with scrubber overlay indicators.

**Architecture:** New `HighlightManager` service persists highlights/bookmarks as JSON. `ChapterView` is refactored to use an `NSTextView`-based `SelectableTextView` for text selection and highlight rendering. `BibleScrubber` draws colored ticks and diamond markers on its Canvas.

**Tech Stack:** SwiftUI, AppKit (NSTextView via NSViewRepresentable), JSON persistence

---

### Task 1: Add Data Models

**Files:**
- Modify: `ESVBible/Models/BibleModels.swift:50` (append after HistoryEntry)

**Step 1: Add Highlight and Bookmark models to BibleModels.swift**

Append after the `HistoryEntry` struct (line 50):

```swift
enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor.systemYellow.withAlphaComponent(0.35)
        case .green: return NSColor.systemGreen.withAlphaComponent(0.35)
        case .blue: return NSColor.systemBlue.withAlphaComponent(0.25)
        case .pink: return NSColor.systemPink.withAlphaComponent(0.3)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.35)
        case .green: return Color.green.opacity(0.35)
        case .blue: return Color.blue.opacity(0.25)
        case .pink: return Color.pink.opacity(0.3)
        }
    }
}

struct Highlight: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int
    let startCharOffset: Int
    let endCharOffset: Int
    let color: HighlightColor
    let createdAt: Date
}

struct Bookmark: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let createdAt: Date
}
```

Note: `import AppKit` and `import SwiftUI` are needed at top of BibleModels.swift for `NSColor` and `Color`.

**Step 2: Commit**

```bash
git add ESVBible/Models/BibleModels.swift
git commit -m "feat: add Highlight, Bookmark, and HighlightColor models"
```

---

### Task 2: Create HighlightManager Service

**Files:**
- Create: `ESVBible/Services/HighlightManager.swift`

**Step 1: Write HighlightManager**

Follow the same pattern as `HistoryManager` (see `ESVBible/Services/HistoryManager.swift`). Key differences:
- Two separate JSON files: `highlights.json` and `bookmarks.json`
- Two separate arrays: `highlights` and `bookmarks`
- Separate `saveHighlights()`/`saveBookmarks()` and `loadHighlights()`/`loadBookmarks()`

```swift
import Foundation

@Observable
class HighlightManager {
    private(set) var highlights: [Highlight] = []
    private(set) var bookmarks: [Bookmark] = []
    private let highlightsURL: URL
    private let bookmarksURL: URL

    init(storageDirectory: URL? = nil) {
        let dir: URL
        if let d = storageDirectory {
            dir = d
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("Spark", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.highlightsURL = dir.appendingPathComponent("highlights.json")
        self.bookmarksURL = dir.appendingPathComponent("bookmarks.json")
        loadHighlights()
        loadBookmarks()
    }

    // MARK: - Highlights

    func addHighlight(book: String, chapter: Int, verse: Int, startChar: Int, endChar: Int, color: HighlightColor) {
        let highlight = Highlight(
            id: UUID(), book: book, chapter: chapter, verse: verse,
            startCharOffset: startChar, endCharOffset: endChar,
            color: color, createdAt: Date()
        )
        highlights.append(highlight)
        saveHighlights()
    }

    func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
        saveHighlights()
    }

    func highlights(forBook book: String, chapter: Int) -> [Highlight] {
        highlights.filter { $0.book == book && $0.chapter == chapter }
    }

    /// Remove all highlights that overlap a given verse+char range (for "remove highlight" action)
    func removeHighlights(book: String, chapter: Int, verse: Int, startChar: Int, endChar: Int) {
        highlights.removeAll { h in
            h.book == book && h.chapter == chapter && h.verse == verse
            && h.startCharOffset < endChar && h.endCharOffset > startChar
        }
        saveHighlights()
    }

    // MARK: - Bookmarks

    func toggleBookmark(book: String, chapter: Int) {
        if let idx = bookmarks.firstIndex(where: { $0.book == book && $0.chapter == chapter }) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.append(Bookmark(id: UUID(), book: book, chapter: chapter, createdAt: Date()))
        }
        saveBookmarks()
    }

    func isBookmarked(book: String, chapter: Int) -> Bool {
        bookmarks.contains { $0.book == book && $0.chapter == chapter }
    }

    // MARK: - Persistence

    private func saveHighlights() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(highlights) else { return }
        try? data.write(to: highlightsURL, options: .atomic)
    }

    private func loadHighlights() {
        guard let data = try? Data(contentsOf: highlightsURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        highlights = (try? decoder.decode([Highlight].self, from: data)) ?? []
    }

    private func saveBookmarks() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(bookmarks) else { return }
        try? data.write(to: bookmarksURL, options: .atomic)
    }

    private func loadBookmarks() {
        guard let data = try? Data(contentsOf: bookmarksURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        bookmarks = (try? decoder.decode([Bookmark].self, from: data)) ?? []
    }
}
```

**Step 2: Add file to Xcode project**

The file needs to be added to `Spark.xcodeproj/project.pbxproj`. This will happen automatically when opening in Xcode, or can be done manually by adding the file reference.

**Step 3: Commit**

```bash
git add ESVBible/Services/HighlightManager.swift
git commit -m "feat: add HighlightManager service with JSON persistence"
```

---

### Task 3: Wire HighlightManager into ContentView

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add state and pass through**

In `ContentView`, add a new `@State`:

```swift
@State private var highlightManager = HighlightManager()
```

Add it after line 4 (`@State private var bibleStore = BibleStore()`).

**Step 2: Pass highlightManager to ReadingPaneView**

Update the `ReadingPaneView(...)` call (around line 29) to include `highlightManager`:

```swift
ReadingPaneView(
    initialPosition: position,
    highlightVerseStart: highlightStart,
    highlightVerseEnd: highlightEnd,
    bibleStore: bibleStore,
    highlightManager: highlightManager,
    onPositionChanged: { visiblePosition = $0 },
    onNavigateRequested: { pos in
        navigateTo(book: pos.bookName, chapter: pos.chapterNumber, verseStart: nil, verseEnd: nil, addToHistory: false)
    }
)
```

**Step 3: Add Cmd+D bookmark shortcut**

Add a new `.onReceive` for bookmark toggling, after the existing `.onReceive` blocks (around line 233):

```swift
.onReceive(NotificationCenter.default.publisher(for: .toggleBookmark)) { _ in
    let position = visiblePosition ?? currentPosition
    guard let position else { return }
    highlightManager.toggleBookmark(book: position.bookName, chapter: position.chapterNumber)
}
```

**Step 4: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: wire HighlightManager into ContentView with Cmd+D bookmark"
```

---

### Task 4: Add Bookmark Keyboard Shortcut and Notification

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift`

**Step 1: Add notification name**

In the `Notification.Name` extension (line 94), add:

```swift
static let toggleBookmark = Notification.Name("toggleBookmark")
```

**Step 2: Add menu command**

In the `CommandGroup` block (after the Toggle History button around line 88), add:

```swift
Divider()

Button("Toggle Bookmark") {
    NotificationCenter.default.post(name: .toggleBookmark, object: nil)
}
.keyboardShortcut("d", modifiers: .command)
```

**Step 3: Commit**

```bash
git add ESVBible/ESVBibleApp.swift
git commit -m "feat: add Cmd+D bookmark toggle menu command"
```

---

### Task 5: Create SelectableTextView (NSViewRepresentable)

**Files:**
- Create: `ESVBible/Views/SelectableTextView.swift`

This is the most complex task. The `SelectableTextView` wraps an `NSTextView` for:
1. Rendering chapter text with highlight backgrounds
2. Detecting text selection
3. Showing a color picker popover on selection
4. Mapping selection ranges back to verse + character offsets

**Step 1: Write SelectableTextView**

```swift
import SwiftUI
import AppKit

struct SelectableTextView: NSViewRepresentable {
    let chapter: Chapter
    let bookName: String
    let highlights: [Highlight]
    let searchHighlightStart: Int?
    let searchHighlightEnd: Int?
    let onHighlight: (Int, Int, Int, HighlightColor) -> Void  // verse, startChar, endChar, color
    let onRemoveHighlights: (Int, Int, Int) -> Void  // verse, startChar, endChar

    func makeNSView(context: Context) -> NSScrollView {
        let textView = HighlightableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        // Store callbacks on coordinator
        context.coordinator.textView = textView
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onRemoveHighlights = onRemoveHighlights

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HighlightableTextView else { return }
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onRemoveHighlights = onRemoveHighlights
        context.coordinator.verseBoundaries = []

        let attrStr = buildAttributedString(coordinator: context.coordinator)
        textView.textStorage?.setAttributedString(attrStr)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Build the NSAttributedString and record verse character boundaries in the coordinator.
    private func buildAttributedString(coordinator: Coordinator) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6

        let bodyFont = NSFont(descriptor: NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body).withDesign(.serif) ?? NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body), size: 16) ?? NSFont.systemFont(ofSize: 16)
        let verseNumFont = NSFont.systemFont(ofSize: 10)

        var boundaries: [(verse: Int, start: Int, end: Int)] = []

        for verse in chapter.verses {
            // Verse number (superscript)
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: verseNumFont,
                .foregroundColor: NSColor.secondaryLabelColor,
                .baselineOffset: 6,
                .paragraphStyle: paragraphStyle
            ]
            let numStr = NSAttributedString(string: "\(verse.number) ", attributes: numAttrs)
            result.append(numStr)

            // Verse text
            let verseStart = result.length
            let isRedLetter = RedLetterService.shared.isRedLetter(book: bookName, chapter: chapter.number, verse: verse.number)
            let isSearchHighlighted = isSearchHighlight(verse.number)

            var textAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .paragraphStyle: paragraphStyle
            ]
            if isSearchHighlighted {
                textAttrs[.foregroundColor] = NSColor.controlAccentColor
            } else if isRedLetter {
                textAttrs[.foregroundColor] = NSColor.systemRed
            } else {
                textAttrs[.foregroundColor] = NSColor.labelColor
            }

            let textStr = NSMutableAttributedString(string: verse.text + " ", attributes: textAttrs)

            // Apply user highlights for this verse
            let verseHighlights = highlights.filter { $0.verse == verse.number }
            for h in verseHighlights {
                let start = max(0, h.startCharOffset)
                let end = min(verse.text.count, h.endCharOffset)
                if start < end {
                    textStr.addAttribute(.backgroundColor, value: h.color.nsColor, range: NSRange(location: start, length: end - start))
                }
            }

            result.append(textStr)
            let verseEnd = result.length
            boundaries.append((verse: verse.number, start: verseStart, end: verseEnd))
        }

        coordinator.verseBoundaries = boundaries
        return result
    }

    private func isSearchHighlight(_ verseNumber: Int) -> Bool {
        guard let start = searchHighlightStart else { return false }
        let end = searchHighlightEnd ?? start
        return verseNumber >= start && verseNumber <= end
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: HighlightableTextView?
        var onHighlight: ((Int, Int, Int, HighlightColor) -> Void)?
        var onRemoveHighlights: ((Int, Int, Int) -> Void)?
        var verseBoundaries: [(verse: Int, start: Int, end: Int)] = []

        /// Map an NSTextView character index to (verse number, char offset within verse text)
        func mapToVerse(_ charIndex: Int) -> (verse: Int, offset: Int)? {
            for boundary in verseBoundaries {
                if charIndex >= boundary.start && charIndex < boundary.end {
                    return (boundary.verse, charIndex - boundary.start)
                }
            }
            return nil
        }
    }
}

// Custom NSTextView subclass to show highlight popover on right-click selection
class HighlightableTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Only show highlight options if there's a selection
        guard selectedRange().length > 0 else {
            return super.menu(for: event)
        }

        for color in HighlightColor.allCases {
            let item = NSMenuItem(title: "Highlight \(color.rawValue.capitalized)", action: #selector(applyHighlight(_:)), keyEquivalent: "")
            item.representedObject = color
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let removeItem = NSMenuItem(title: "Remove Highlight", action: #selector(removeHighlight(_:)), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(NSMenuItem.separator())

        // Add standard copy item
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        menu.addItem(copyItem)

        return menu
    }

    @objc private func applyHighlight(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? HighlightColor,
              let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }

        let range = selectedRange()
        guard range.length > 0 else { return }

        // Map selection to verse boundaries
        guard let startMap = coordinator.mapToVerse(range.location),
              let endMap = coordinator.mapToVerse(range.location + range.length - 1) else { return }

        // For simplicity, if selection spans multiple verses, create a highlight per verse
        for boundary in coordinator.verseBoundaries {
            let overlapStart = max(range.location, boundary.start)
            let overlapEnd = min(range.location + range.length, boundary.end)
            if overlapStart < overlapEnd {
                let charStart = overlapStart - boundary.start
                let charEnd = overlapEnd - boundary.start
                coordinator.onHighlight?(boundary.verse, charStart, charEnd, color)
            }
        }
    }

    @objc private func removeHighlight(_ sender: NSMenuItem) {
        guard let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }

        let range = selectedRange()
        guard range.length > 0 else { return }

        for boundary in coordinator.verseBoundaries {
            let overlapStart = max(range.location, boundary.start)
            let overlapEnd = min(range.location + range.length, boundary.end)
            if overlapStart < overlapEnd {
                let charStart = overlapStart - boundary.start
                let charEnd = overlapEnd - boundary.start
                coordinator.onRemoveHighlights?(boundary.verse, charStart, charEnd)
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift
git commit -m "feat: add SelectableTextView with NSTextView for text selection and highlighting"
```

---

### Task 6: Refactor ChapterView to Use SelectableTextView

**Files:**
- Modify: `ESVBible/ReadingPaneView.swift`

**Step 1: Add highlightManager parameter to ReadingPaneView**

Add `let highlightManager: HighlightManager` to `ReadingPaneView` (after line 13, `let bibleStore: BibleStore`).

**Step 2: Pass highlightManager to ChapterView**

Update `ChapterView` init in the `ForEach` (around line 30) to include `highlightManager`:

```swift
ChapterView(
    chapter: chapter,
    bookName: book.name,
    highlightVerseStart: position == initialPosition ? highlightVerseStart : nil,
    highlightVerseEnd: position == initialPosition ? highlightVerseEnd : nil,
    highlightManager: highlightManager
)
```

**Step 3: Refactor ChapterView**

Replace the private `ChapterView` struct (lines 126-179) to use `SelectableTextView` and show a bookmark icon:

```swift
private struct ChapterView: View {
    let chapter: Chapter
    let bookName: String
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?
    let highlightManager: HighlightManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(bookName) \(chapter.number)")
                    .font(.title)
                    .fontWeight(.semibold)

                if highlightManager.isBookmarked(book: bookName, chapter: chapter.number) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.accentColor)
                        .font(.title3)
                }
            }
            .padding(.bottom, 16)

            SelectableTextView(
                chapter: chapter,
                bookName: bookName,
                highlights: highlightManager.highlights(forBook: bookName, chapter: chapter.number),
                searchHighlightStart: highlightVerseStart,
                searchHighlightEnd: highlightVerseEnd,
                onHighlight: { verse, startChar, endChar, color in
                    highlightManager.addHighlight(
                        book: bookName, chapter: chapter.number,
                        verse: verse, startChar: startChar, endChar: endChar, color: color
                    )
                },
                onRemoveHighlights: { verse, startChar, endChar in
                    highlightManager.removeHighlights(
                        book: bookName, chapter: chapter.number,
                        verse: verse, startChar: startChar, endChar: endChar
                    )
                }
            )
            .frame(minHeight: 100)

            Divider()
                .padding(.vertical, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**Important note:** The `SelectableTextView` is inside an `NSScrollView` by default. Since the outer `ReadingPaneView` already has a `ScrollView`, we need the `SelectableTextView` to NOT scroll independently. In `SelectableTextView.makeNSView`, set:
- `scrollView.hasVerticalScroller = false`  (already done in Task 5)
- The `NSTextView` should size to fit its content. Add `.frame(minHeight:)` or use an `intrinsicContentSize` approach to let it expand.

This may require adding height calculation to `SelectableTextView` — use `textView.layoutManager?.usedRect(for:)` to get the text height and report it back via a `@Binding` or `PreferenceKey`.

**Step 4: Commit**

```bash
git add ESVBible/ReadingPaneView.swift
git commit -m "feat: refactor ChapterView to use SelectableTextView with highlight support"
```

---

### Task 7: Add Scrubber Overlay Indicators

**Files:**
- Modify: `ESVBible/BibleScrubber.swift`

**Step 1: Add highlightManager parameter**

Add to `BibleScrubber` struct (after line 115 `let onNavigate:`):

```swift
let highlightManager: HighlightManager
```

**Step 2: Draw highlight ticks and bookmark markers in Canvas**

Replace the Canvas block (lines 153-167) with an expanded version that draws markers before the thumb:

```swift
Canvas { context, size in
    let trackX = size.width / 2
    let trackRect = CGRect(x: trackX - 1, y: trackTop, width: 2, height: trackHeight)
    context.fill(Path(roundedRect: trackRect, cornerRadius: 1), with: .color(.secondary.opacity(0.3)))

    // Draw highlight ticks (left of track)
    let totalChapters = CGFloat(max(1, BibleStore.totalChapters - 1))
    for highlight in highlightManager.highlights {
        let idx = CGFloat(BibleStore.globalChapterIndex(book: highlight.book, chapter: highlight.chapter))
        let fraction = idx / totalChapters
        let y = trackTop + fraction * trackHeight
        let tickRect = CGRect(x: trackX - 5, y: y - 1, width: 3, height: 2)
        context.fill(Path(roundedRect: tickRect, cornerRadius: 0.5), with: .color(Color(nsColor: highlight.color.nsColor)))
    }

    // Draw bookmark markers (right of track)
    for bookmark in highlightManager.bookmarks {
        let idx = CGFloat(BibleStore.globalChapterIndex(book: bookmark.book, chapter: bookmark.chapter))
        let fraction = idx / totalChapters
        let y = trackTop + fraction * trackHeight
        // Diamond shape
        var diamond = Path()
        diamond.move(to: CGPoint(x: trackX + 3, y: y - 3))
        diamond.addLine(to: CGPoint(x: trackX + 6, y: y))
        diamond.addLine(to: CGPoint(x: trackX + 3, y: y + 3))
        diamond.addLine(to: CGPoint(x: trackX, y: y))
        diamond.closeSubpath()
        context.fill(diamond, with: .color(.accentColor))
    }

    // Thumb
    let thumbWidth: CGFloat = 6
    let thumbHeight: CGFloat = 30
    let thumbRect = CGRect(
        x: trackX - thumbWidth / 2,
        y: thumbY - thumbHeight / 2,
        width: thumbWidth,
        height: thumbHeight
    )
    context.fill(Path(roundedRect: thumbRect, cornerRadius: 3), with: .color(.accentColor))
}
.allowsHitTesting(false)
```

**Step 3: Update BibleScrubber call site in ReadingPaneView**

In `ReadingPaneView` (around line 53), update the `BibleScrubber` instantiation:

```swift
BibleScrubber(
    currentPosition: visiblePosition ?? initialPosition,
    onNavigate: { position in
        onNavigateRequested?(position)
    },
    highlightManager: highlightManager
)
```

**Step 4: Commit**

```bash
git add ESVBible/BibleScrubber.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: add highlight ticks and bookmark markers to scrubber overlay"
```

---

### Task 8: Handle SelectableTextView Height Sizing

**Files:**
- Modify: `ESVBible/Views/SelectableTextView.swift`

The `SelectableTextView` needs to report its content height so it doesn't collapse inside the outer `ScrollView`.

**Step 1: Add height binding**

Add a `@Binding var contentHeight: CGFloat` parameter to `SelectableTextView`. In `updateNSView`, after setting the attributed string, calculate and update the height:

```swift
DispatchQueue.main.async {
    if let layoutManager = textView.layoutManager, let container = textView.textContainer {
        layoutManager.ensureLayout(for: container)
        let usedRect = layoutManager.usedRect(for: container)
        contentHeight = usedRect.height
    }
}
```

In `ReadingPaneView`'s `ChapterView`, use `@State private var textHeight: CGFloat = 100` and apply `.frame(height: textHeight)` to the `SelectableTextView`.

**Step 2: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: add dynamic height calculation to SelectableTextView"
```

---

### Task 9: Build and Test

**Step 1: Build the project**

Run: `xcodebuild -scheme Spark -configuration Debug build`

Fix any compilation errors.

**Step 2: Manual testing checklist**

- [ ] App launches and shows Bible text as before
- [ ] Select text, right-click → see highlight color options
- [ ] Apply yellow highlight → text gets yellow background
- [ ] Apply green highlight → text gets green background
- [ ] Highlight persists after restarting app
- [ ] Cmd+D toggles bookmark icon in chapter header
- [ ] Bookmarked chapters show diamond marker on scrubber
- [ ] Highlighted chapters show colored tick marks on scrubber
- [ ] Scrolling/scrubbing still works smoothly
- [ ] Search highlighting still works
- [ ] Red letter text still displays correctly
- [ ] Remove highlight via right-click context menu works

**Step 3: Fix any issues found during testing**

**Step 4: Final commit**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```
