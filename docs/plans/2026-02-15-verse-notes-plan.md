# Verse Notes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add rich text notes attached to verse ranges, with right-click creation, inline indicators, a notes sidebar, and scrubber markers.

**Architecture:** Notes are stored as a `Note` model with RTF data in `notes.json`, managed by `HighlightManager`. The UI uses NSTextView-based rich text editing in popovers, inline note icons in the reading pane, and an inspector sidebar for browsing all notes.

**Tech Stack:** SwiftUI, AppKit (NSTextView, NSViewRepresentable), RTF serialization, JSON persistence

---

### Task 1: Add Note model

**Files:**
- Modify: `ESVBible/Models/BibleModels.swift:96-101` (after `Bookmark` struct)
- Test: `ESVBibleTests/BibleModelsTests.swift`

**Step 1: Write the failing test**

Add to `ESVBibleTests/BibleModelsTests.swift`:

```swift
func testNoteEncoding() throws {
    let rtfString = "Test note content"
    let attrStr = NSAttributedString(string: rtfString)
    let rtfData = try! attrStr.data(
        from: NSRange(location: 0, length: attrStr.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )

    let note = Note(
        id: UUID(),
        book: "John",
        chapter: 3,
        verseStart: 16,
        verseEnd: 18,
        rtfData: rtfData,
        createdAt: Date(),
        updatedAt: Date()
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(note)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(Note.self, from: data)

    XCTAssertEqual(decoded.book, "John")
    XCTAssertEqual(decoded.chapter, 3)
    XCTAssertEqual(decoded.verseStart, 16)
    XCTAssertEqual(decoded.verseEnd, 18)
    XCTAssertEqual(decoded.rtfData, rtfData)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/BibleModelsTests/testNoteEncoding 2>&1 | tail -20`
Expected: FAIL — `Note` type not found

**Step 3: Write minimal implementation**

Add to `ESVBible/Models/BibleModels.swift` after the `Bookmark` struct:

```swift
struct Note: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let rtfData: Data
    let createdAt: Date
    var updatedAt: Date
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/BibleModelsTests/testNoteEncoding 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add ESVBible/Models/BibleModels.swift ESVBibleTests/BibleModelsTests.swift
git commit -m "feat: add Note model for verse range annotations"
```

---

### Task 2: Add notes CRUD to HighlightManager

**Files:**
- Modify: `ESVBible/Services/HighlightManager.swift`
- Test: `ESVBibleTests/HighlightManagerTests.swift` (create if needed, or add to existing)

**Step 1: Write the failing tests**

Create `ESVBibleTests/HighlightManagerTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class HighlightManagerTests: XCTestCase {
    var manager: HighlightManager!
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = HighlightManager(storageDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func sampleRTFData(_ text: String) -> Data {
        let attrStr = NSAttributedString(string: text)
        return try! attrStr.data(
            from: NSRange(location: 0, length: attrStr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    func testAddNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Test"))
        XCTAssertEqual(manager.notes.count, 1)
        XCTAssertEqual(manager.notes.first?.book, "John")
        XCTAssertEqual(manager.notes.first?.verseStart, 16)
        XCTAssertEqual(manager.notes.first?.verseEnd, 18)
    }

    func testUpdateNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Original"))
        let noteID = manager.notes.first!.id
        let newData = sampleRTFData("Updated")
        manager.updateNote(id: noteID, rtfData: newData)
        XCTAssertEqual(manager.notes.first?.rtfData, newData)
    }

    func testRemoveNote() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Test"))
        let noteID = manager.notes.first!.id
        manager.removeNote(id: noteID)
        XCTAssertEqual(manager.notes.count, 0)
    }

    func testNotesForChapter() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Note 1"))
        manager.addNote(book: "John", chapter: 5, verseStart: 1, verseEnd: 1, rtfData: sampleRTFData("Note 2"))
        let ch3Notes = manager.notes(forBook: "John", chapter: 3)
        XCTAssertEqual(ch3Notes.count, 1)
        XCTAssertEqual(ch3Notes.first?.verseStart, 16)
    }

    func testNotesPersistence() {
        manager.addNote(book: "John", chapter: 3, verseStart: 16, verseEnd: 18, rtfData: sampleRTFData("Persisted"))
        let manager2 = HighlightManager(storageDirectory: tempDir)
        XCTAssertEqual(manager2.notes.count, 1)
        XCTAssertEqual(manager2.notes.first?.book, "John")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/HighlightManagerTests 2>&1 | tail -20`
Expected: FAIL — `notes` property and methods not found

**Step 3: Write implementation**

Add to `ESVBible/Services/HighlightManager.swift`:

1. Add property and URL:
```swift
private(set) var notes: [Note] = []
private let notesURL: URL
```

2. In `init`, add:
```swift
self.notesURL = dir.appendingPathComponent("notes.json")
// after existing loads:
loadNotes()
```

3. Add CRUD methods:
```swift
// MARK: - Notes

func addNote(book: String, chapter: Int, verseStart: Int, verseEnd: Int, rtfData: Data) {
    let note = Note(
        id: UUID(),
        book: book,
        chapter: chapter,
        verseStart: verseStart,
        verseEnd: verseEnd,
        rtfData: rtfData,
        createdAt: Date(),
        updatedAt: Date()
    )
    notes.append(note)
    saveNotes()
}

func updateNote(id: UUID, rtfData: Data) {
    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
    notes[index] = Note(
        id: notes[index].id,
        book: notes[index].book,
        chapter: notes[index].chapter,
        verseStart: notes[index].verseStart,
        verseEnd: notes[index].verseEnd,
        rtfData: rtfData,
        createdAt: notes[index].createdAt,
        updatedAt: Date()
    )
    saveNotes()
}

func removeNote(id: UUID) {
    notes.removeAll { $0.id == id }
    saveNotes()
}

func notes(forBook book: String, chapter: Int) -> [Note] {
    notes.filter { $0.book == book && $0.chapter == chapter }
}
```

4. Add persistence methods:
```swift
private func saveNotes() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(notes) else { return }
    try? data.write(to: notesURL, options: .atomic)
}

private func loadNotes() {
    guard let data = try? Data(contentsOf: notesURL) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    notes = (try? decoder.decode([Note].self, from: data)) ?? []
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/HighlightManagerTests 2>&1 | tail -20`
Expected: PASS

**Step 5: Commit**

```bash
git add ESVBible/Services/HighlightManager.swift ESVBibleTests/HighlightManagerTests.swift
git commit -m "feat: add notes CRUD to HighlightManager with persistence"
```

---

### Task 3: Create NoteEditorView (rich text editor component)

**Files:**
- Create: `ESVBible/Views/NoteEditorView.swift`

**Step 1: Create the rich text editor**

Create `ESVBible/Views/NoteEditorView.swift`:

```swift
import SwiftUI
import AppKit

struct NoteEditorView: NSViewRepresentable {
    @Binding var rtfData: Data
    var isEditable: Bool = true

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Load initial content
        if !rtfData.isEmpty {
            if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrStr)
            }
        }

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Only update if data changed externally (not from typing)
        guard !context.coordinator.isEditing else { return }
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if !rtfData.isEmpty {
            if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrStr)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rtfData: $rtfData)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        var rtfData: Binding<Data>
        var isEditing = false

        init(rtfData: Binding<Data>) {
            self.rtfData = rtfData
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }
            isEditing = true
            let range = NSRange(location: 0, length: textStorage.length)
            if let data = try? textStorage.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                rtfData.wrappedValue = data
            }
            isEditing = false
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/Views/NoteEditorView.swift
git commit -m "feat: add NoteEditorView rich text editor component"
```

---

### Task 4: Create NotePopoverView

**Files:**
- Create: `ESVBible/Views/NotePopoverView.swift`

**Step 1: Create the popover view**

Create `ESVBible/Views/NotePopoverView.swift`:

```swift
import SwiftUI

struct NotePopoverView: View {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let existingNote: Note?
    let onSave: (Data) -> Void
    let onDelete: (() -> Void)?

    @State private var rtfData: Data
    @Environment(\.dismiss) private var dismiss

    init(book: String, chapter: Int, verseStart: Int, verseEnd: Int, existingNote: Note?, onSave: @escaping (Data) -> Void, onDelete: (() -> Void)?) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
        self.existingNote = existingNote
        self.onSave = onSave
        self.onDelete = onDelete
        self._rtfData = State(initialValue: existingNote?.rtfData ?? Data())
    }

    private var referenceText: String {
        if verseStart == verseEnd {
            return "\(book) \(chapter):\(verseStart)"
        }
        return "\(book) \(chapter):\(verseStart)-\(verseEnd)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(referenceText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()

                HStack(spacing: 4) {
                    Button {
                        toggleBold()
                    } label: {
                        Image(systemName: "bold")
                    }
                    .buttonStyle(.plain)
                    .help("Bold")

                    Button {
                        toggleItalic()
                    } label: {
                        Image(systemName: "italic")
                    }
                    .buttonStyle(.plain)
                    .help("Italic")

                    Button {
                        toggleUnderline()
                    } label: {
                        Image(systemName: "underline")
                    }
                    .buttonStyle(.plain)
                    .help("Underline")
                }
            }

            NoteEditorView(rtfData: $rtfData)
                .frame(minHeight: 100, maxHeight: 200)

            HStack {
                if onDelete != nil {
                    Button("Delete", role: .destructive) {
                        onDelete?()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Save") {
                    onSave(rtfData)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(rtfData.isEmpty)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func toggleBold() {
        NSApp.sendAction(#selector(NSFontManager.addFontTrait(_:)), to: nil, from: NSFontManager.shared)
        NSFontManager.shared.addFontTrait(NSFontManager.shared)
    }

    private func toggleItalic() {
        NSFontManager.shared.addFontTrait(NSFontManager.shared)
    }

    private func toggleUnderline() {
        NSApp.sendAction(#selector(NSText.underline(_:)), to: nil, from: nil)
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/Views/NotePopoverView.swift
git commit -m "feat: add NotePopoverView with formatting toolbar"
```

---

### Task 5: Add "Add Note" to context menu and inline note icons

**Files:**
- Modify: `ESVBible/Views/SelectableTextView.swift`

**Step 1: Add note callback and inline indicators**

In `SelectableTextView`, add new properties:

```swift
let notes: [Note]
let onAddNote: (Int, Int) -> Void  // verseStart, verseEnd
let onEditNote: (Note) -> Void
```

Update `makeNSView` and `makeCoordinator` to pass these through to the coordinator:
```swift
context.coordinator.onAddNote = onAddNote
context.coordinator.onEditNote = onEditNote
context.coordinator.notes = notes
```

Update `updateNSView` similarly:
```swift
context.coordinator.onAddNote = onAddNote
context.coordinator.onEditNote = onEditNote
context.coordinator.notes = notes
```

In the `Coordinator` class, add:
```swift
var onAddNote: ((Int, Int) -> Void)?
var onEditNote: ((Note) -> Void)?
var notes: [Note] = []
```

In `buildAttributedString`, after rendering each verse number, check if that verse has a note and insert a note icon indicator (using a text attachment or a unicode symbol like "📝" sized small) before the verse text. Use `NSTextAttachment` with an `NSImage` of `text.bubble.fill` for a native look.

Actually, a simpler approach: add a small inline indicator by inserting a tinted `text.bubble` SF Symbol character using `NSTextAttachment`:

```swift
// After verse number, before verse text:
let verseNotes = notes.filter { verse.number >= $0.verseStart && verse.number <= $0.verseEnd }
if !verseNotes.isEmpty {
    let attachment = NSTextAttachment()
    let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    let image = NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: "Note")?
        .withSymbolConfiguration(config)
    attachment.image = image
    let attachStr = NSMutableAttributedString(attachment: attachment)
    attachStr.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: NSRange(location: 0, length: attachStr.length))
    attachStr.append(NSAttributedString(string: " "))
    result.append(attachStr)
}
```

In `HighlightableTextView`, add "Add Note" to the context menu:

```swift
menu.addItem(NSMenuItem.separator())

let noteItem = NSMenuItem(title: "Add Note", action: #selector(addNote(_:)), keyEquivalent: "")
noteItem.target = self
menu.addItem(noteItem)
```

Add the action method:
```swift
@objc private func addNote(_ sender: NSMenuItem) {
    guard let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }
    let range = selectedRange()
    guard range.length > 0 else { return }

    // Find verse range from selection
    var verseStart = Int.max
    var verseEnd = Int.min
    for boundary in coordinator.verseBoundaries {
        let overlapStart = max(range.location, boundary.start)
        let overlapEnd = min(range.location + range.length, boundary.end)
        if overlapStart < overlapEnd {
            verseStart = min(verseStart, boundary.verse)
            verseEnd = max(verseEnd, boundary.verse)
        }
    }

    guard verseStart <= verseEnd else { return }
    coordinator.onAddNote?(verseStart, verseEnd)
}
```

Also handle clicking on note icons: when the user clicks a note attachment, trigger `onEditNote`. Override `mouseDown(with:)` in `HighlightableTextView` to detect clicks on attachments and check if the verse has a note.

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (may need to fix callers first — see Task 6)

**Step 3: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift
git commit -m "feat: add note context menu and inline note icons"
```

---

### Task 6: Wire up notes in ChapterView and ReadingPaneView

**Files:**
- Modify: `ESVBible/ReadingPaneView.swift`

**Step 1: Update ChapterView**

Add `notes` parameter to `ChapterView` and a note popover state:

```swift
private struct ChapterView: View {
    // existing properties...
    let notes: [Note]
    let onAddNote: (Int, Int) -> Void
    let onEditNote: (Note) -> Void
    let onSaveNote: (UUID, Data) -> Void
    let onDeleteNote: (UUID) -> Void
    // existing state...
    @State private var showNotePopover = false
    @State private var notePopoverVerseStart: Int = 1
    @State private var notePopoverVerseEnd: Int = 1
    @State private var editingNote: Note? = nil
```

Pass `notes`, `onAddNote`, `onEditNote` to `SelectableTextView`.

Add popover modifier to show `NotePopoverView` when creating/editing notes:

```swift
.popover(isPresented: $showNotePopover) {
    NotePopoverView(
        book: bookName,
        chapter: chapter.number,
        verseStart: notePopoverVerseStart,
        verseEnd: notePopoverVerseEnd,
        existingNote: editingNote,
        onSave: { rtfData in
            if let note = editingNote {
                onSaveNote(note.id, rtfData)
            } else {
                // Create new — handled by parent
                let manager = highlightManager
                manager.addNote(book: bookName, chapter: chapter.number, verseStart: notePopoverVerseStart, verseEnd: notePopoverVerseEnd, rtfData: rtfData)
            }
            showNotePopover = false
            editingNote = nil
        },
        onDelete: editingNote != nil ? {
            if let note = editingNote {
                onDeleteNote(note.id)
            }
            showNotePopover = false
            editingNote = nil
        } : nil
    )
}
```

**Step 2: Update ReadingPaneView**

Pass `highlightManager.notes(forBook:chapter:)` to `ChapterView`, and wire up the add/edit/save/delete callbacks.

**Step 3: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ESVBible/ReadingPaneView.swift
git commit -m "feat: wire up notes in ChapterView and ReadingPaneView"
```

---

### Task 7: Create NotesSidebarView

**Files:**
- Create: `ESVBible/Views/NotesSidebarView.swift`

**Step 1: Create the sidebar view**

Create `ESVBible/Views/NotesSidebarView.swift`, following the pattern of `HistorySidebarView`:

```swift
import SwiftUI

struct NotesSidebarView: View {
    let notes: [Note]
    let onSelect: (Note) -> Void
    let onDelete: (UUID) -> Void

    private var groupedNotes: [(String, [Note])] {
        let grouped = Dictionary(grouping: notes) { "\($0.book) \($0.chapter)" }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.verseStart < $1.verseStart }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(notes.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                List {
                    ForEach(groupedNotes, id: \.0) { group, groupNotes in
                        Section(group) {
                            ForEach(groupNotes) { note in
                                Button {
                                    onSelect(note)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(noteReference(note))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(notePlainText(note))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                        Text(note.updatedAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        onDelete(note.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func noteReference(_ note: Note) -> String {
        if note.verseStart == note.verseEnd {
            return "\(note.book) \(note.chapter):\(note.verseStart)"
        }
        return "\(note.book) \(note.chapter):\(note.verseStart)-\(note.verseEnd)"
    }

    private func notePlainText(_ note: Note) -> String {
        guard let attrStr = NSAttributedString(rtf: note.rtfData, documentAttributes: nil) else {
            return ""
        }
        return attrStr.string
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/Views/NotesSidebarView.swift
git commit -m "feat: add NotesSidebarView for browsing all notes"
```

---

### Task 8: Add notes sidebar toggle to ContentView

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add notes sidebar state and inspector**

Add state variable:
```swift
@State private var showNotes = false
```

Add notification receiver in `body`:
```swift
.onReceive(NotificationCenter.default.publisher(for: .toggleNotes)) { _ in
    showNotes.toggle()
}
```

Add another `.inspector` modifier (or combine with history into a tab-based inspector). The simpler approach is a second inspector. However, SwiftUI only supports one `.inspector` per view. Instead, combine them:

Replace the existing `.inspector` with a combined one that switches between History and Notes based on which is active:

```swift
.inspector(isPresented: Binding(
    get: { showHistory || showNotes },
    set: { newValue in
        if !newValue {
            showHistory = false
            showNotes = false
        }
    }
)) {
    if showNotes {
        NotesSidebarView(
            notes: highlightManager.notes,
            onSelect: { note in
                showNotes = false
                navigateTo(book: note.book, chapter: note.chapter, verseStart: note.verseStart, verseEnd: note.verseEnd, addToHistory: true)
            },
            onDelete: { id in
                highlightManager.removeNote(id: id)
            }
        )
        .frame(minWidth: 150, maxWidth: 300)
    } else {
        HistorySidebarView(
            entries: historyManager.entries,
            onSelect: { entry in
                navigateToHistory(entry)
            },
            onClear: {
                historyManager.clearHistory()
            }
        )
        .frame(minWidth: 150, maxWidth: 300)
    }
}
```

Make sure toggling one closes the other:
```swift
.onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { _ in
    if showNotes { showNotes = false }
    showHistory.toggle()
}
.onReceive(NotificationCenter.default.publisher(for: .toggleNotes)) { _ in
    if showHistory { showHistory = false }
    showNotes.toggle()
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: add notes sidebar toggle in ContentView"
```

---

### Task 9: Add Cmd+N shortcut and notification

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift`

**Step 1: Add notification name and menu command**

Add to the `Notification.Name` extension:
```swift
static let toggleNotes = Notification.Name("toggleNotes")
```

Add menu command in `ESVBibleApp.body` commands, after "Toggle History":
```swift
Button("Toggle Notes") {
    NotificationCenter.default.post(name: .toggleNotes, object: nil)
}
.keyboardShortcut("n", modifiers: .command)
```

**Step 2: Update keyboard shortcuts overlay**

In `ContentView`, add to `shortcutItems`:
```swift
("Toggle Notes", "\u{2318}N"),
```

**Step 3: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ESVBible/ESVBibleApp.swift ESVBible/ContentView.swift
git commit -m "feat: add Cmd+N shortcut for notes sidebar"
```

---

### Task 10: Add note markers to scrubber

**Files:**
- Modify: `ESVBible/BibleScrubber.swift`

**Step 1: Add note tick marks to the scrubber Canvas**

In the `Canvas` drawing block in `BibleScrubber`, after the bookmark markers section, add note markers. Use a small circle or square icon to the right of the track, distinct from bookmarks:

```swift
// Note markers (right of track, below bookmarks) — small filled circle
for note in highlightManager.notes {
    let idx = CGFloat(BibleStore.globalChapterIndex(book: note.book, chapter: note.chapter))
    let fraction = idx / totalChapters
    let y = trackTop + fraction * trackHeight
    let noteRect = CGRect(x: trackX + 8, y: y - 2, width: 4, height: 4)
    context.fill(Path(ellipse: in: noteRect), with: .color(.orange.opacity(0.8)))
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/BibleScrubber.swift
git commit -m "feat: add note markers to scrubber"
```

---

### Task 11: Run full test suite and verify

**Step 1: Run all tests**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -30`
Expected: All tests PASS

**Step 2: Build and run the app**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Final commit if any fixups needed**

```bash
git add -A
git commit -m "fix: address any remaining issues from verse notes implementation"
```
