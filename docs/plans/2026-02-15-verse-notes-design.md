# Verse Notes Feature Design

## Overview

Add the ability to attach rich text notes to verse ranges in Zephyr. Notes are created via right-click context menu, viewed inline via note icons, browsed in a side panel, and indicated on the scrubber.

## Data Model

```swift
struct Note: Codable, Identifiable {
    let id: UUID
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let rtfData: Data        // NSAttributedString serialized as RTF
    let createdAt: Date
    var updatedAt: Date
}
```

- Persisted as `notes.json` in `~/Library/Application Support/Zephyr/`
- Managed by `HighlightManager` (renamed or extended to handle notes alongside highlights and bookmarks)
- RTF data stored as base64-encoded Data in JSON

## Interaction Design

### Creating Notes
- Select text in the reading pane, right-click, choose "Add Note"
- A popover appears near the selection with an NSTextView-based rich text editor
- Small formatting toolbar: bold, italic, underline
- Auto-saves on popover dismiss

### Inline Note Indicators
- Small `text.bubble` icon in the verse number area for verses with notes
- Click icon to open the note popover for viewing/editing
- Icon uses accent color to stand out subtly

### Notes Side Panel
- Toggleable inspector panel (like existing history sidebar) via `Cmd+N`
- Lists all notes grouped by book/chapter
- Shows verse reference and a preview of note text
- Clicking a note navigates to its location

### Scrubber Indicator
- Small markers on the scrubber showing chapters with notes
- Consistent with existing bookmark indicators

## Technical Approach

### Rich Text Editor (NSViewRepresentable)
- Wraps `NSTextView` for WYSIWYG editing
- Formatting toolbar with bold/italic/underline toggle buttons
- Serializes to RTF via `NSAttributedString.data(from:documentAttributes:)` with `.rtf` type
- Deserializes via `NSAttributedString(data:options:documentAttributes:)` with `.rtf` type

### Storage in HighlightManager
- Add `notes: [Note]` property
- Add CRUD methods: `addNote`, `updateNote`, `removeNote`, `notes(forBook:chapter:)`
- Persist to `notes.json` with same pattern as highlights/bookmarks

### Context Menu Extension
- Add "Add Note" item to `HighlightableTextView.menu(for:)`
- Determine verse range from selection using existing `verseBoundaries`

### UI Components
- `NoteEditorView` — NSViewRepresentable wrapping NSTextView with formatting toolbar
- `NotePopoverView` — popover containing NoteEditorView with save/delete actions
- `NotesSidebarView` — inspector panel listing all notes
- Inline note icon overlay in `SelectableTextView`

### Keyboard Shortcut
- `Cmd+N` — toggle notes side panel
- Added to ESVBibleApp menu commands and keyboard shortcuts overlay

## Files Modified
- `ESVBible/Models/BibleModels.swift` — add `Note` model
- `ESVBible/Services/HighlightManager.swift` — add notes storage/CRUD
- `ESVBible/Views/SelectableTextView.swift` — add "Add Note" to context menu, inline note icons
- `ESVBible/ReadingPaneView.swift` — pass note-related callbacks
- `ESVBible/ContentView.swift` — add notes side panel toggle, state
- `ESVBible/ESVBibleApp.swift` — add Cmd+N menu command

## New Files
- `ESVBible/Views/NoteEditorView.swift` — rich text editor component
- `ESVBible/Views/NotePopoverView.swift` — popover wrapper
- `ESVBible/Views/NotesSidebarView.swift` — notes list sidebar
