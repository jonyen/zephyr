# Tab Support Design

**Date:** 2026-02-19

## Overview

Add native macOS tab support with ⌘T (new tab, same chapter as current) and ⇧⌘T (reopen closed tab). Remove the existing ⌘T binding from Table of Contents.

## Architecture

Switch `WindowGroup` to the value-based form `WindowGroup(for: ChapterPosition.self)`. This lets SwiftUI pass a `ChapterPosition` into each new window/tab at creation time, so new tabs open at the exact chapter the user is currently reading.

## Components

### ChapterPosition.swift
Add `Codable` conformance. Required for `WindowGroup(for:)` to serialize and pass values between windows.

### ESVBibleApp.swift
- Switch `WindowGroup { ContentView() }` → `WindowGroup(for: ChapterPosition.self) { $position in ContentView(initialPosition: position) }`
- Remove `.keyboardShortcut("t", modifiers: .command)` from the Table of Contents button
- Add `⌘T` command posting `.newTab`
- Add `⇧⌘T` command posting `.reopenClosedTab`
- Register `.newTab` and `.reopenClosedTab` in the `Notification.Name` extension

### ContentView.swift
- Accept optional `initialPosition: ChapterPosition?` parameter; on `onAppear`, navigate to it if non-nil (else fall back to `@AppStorage` defaults)
- Add `@Environment(\.openWindow)`
- Handle `.newTab`: call `openWindow(value: visiblePosition ?? currentPosition ?? default)`
- Handle `.reopenClosedTab`: pop from `ClosedTabsStack.shared` and call `openWindow(value:)` if non-nil
- Add `onDisappear`: push `visiblePosition ?? currentPosition` to `ClosedTabsStack.shared`
- Update shortcuts overlay: remove Table of Contents `⌘T` entry, add "New Tab `⌘T`" and "Reopen Closed Tab `⇧⌘T`"

### ClosedTabsStack.swift (new)
Lightweight singleton backed by `UserDefaults`. Stores a `[ChapterPosition]` JSON-encoded array (capped at 20 entries). Exposes `push(_ position:)` and `pop() -> ChapterPosition?`.

## Data Flow

```
User presses ⌘T
  → ESVBibleApp posts .newTab
  → ContentView receives .newTab
  → reads visiblePosition (current scroll position)
  → calls openWindow(value: position)
  → new WindowGroup instance created with that ChapterPosition
  → ContentView(initialPosition: position) navigates there on appear

User closes tab
  → ContentView.onDisappear fires
  → pushes position to ClosedTabsStack

User presses ⇧⌘T
  → ESVBibleApp posts .reopenClosedTab
  → ContentView receives .reopenClosedTab
  → pops position from ClosedTabsStack
  → calls openWindow(value: position)
```

## Error Handling

- If `ClosedTabsStack` is empty, `⇧⌘T` is a no-op (no window opened, no error shown)
- If `visiblePosition` and `currentPosition` are both nil when `⌘T` is pressed, fall back to Genesis 1
