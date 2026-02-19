# Tab Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add ⌘T (new tab at current chapter) and ⇧⌘T (reopen closed tab), removing the existing ⌘T binding from Table of Contents.

**Architecture:** Switch `WindowGroup` to the value-based `WindowGroup(for: ChapterPosition.self)` so SwiftUI can pass a chapter position into each new tab at creation time. A `ClosedTabsStack` singleton (UserDefaults-backed) tracks closed tab positions for ⇧⌘T. `ContentView` handles both notifications using `@Environment(\.openWindow)`.

**Tech Stack:** SwiftUI (macOS 14+), XCTest, UserDefaults

---

### Task 1: Make ChapterPosition Codable

**Files:**
- Modify: `ESVBible/ChapterPosition.swift`
- Test: `ESVBibleTests/ChapterPositionTests.swift` (create)

**Step 1: Create the test file**

```swift
// ESVBibleTests/ChapterPositionTests.swift
import XCTest
@testable import ESVBible

final class ChapterPositionTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let position = ChapterPosition(bookName: "John", chapterNumber: 3)
        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(ChapterPosition.self, from: data)
        XCTAssertEqual(decoded.bookName, "John")
        XCTAssertEqual(decoded.chapterNumber, 3)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' -only-testing:ESVBibleTests/ChapterPositionTests 2>&1 | tail -20`

Expected: FAIL — `ChapterPosition` does not conform to `Encodable`

**Step 3: Add Codable to ChapterPosition**

Replace the entire file:

```swift
struct ChapterPosition: Equatable, Hashable, Codable {
    let bookName: String
    let chapterNumber: Int
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' -only-testing:ESVBibleTests/ChapterPositionTests 2>&1 | tail -20`

Expected: PASS

**Step 5: Commit**

```bash
git add ESVBible/ChapterPosition.swift ESVBibleTests/ChapterPositionTests.swift
git commit -m "feat: make ChapterPosition Codable for WindowGroup value passing"
```

---

### Task 2: Create ClosedTabsStack

**Files:**
- Create: `ESVBible/ClosedTabsStack.swift`
- Test: `ESVBibleTests/ClosedTabsStackTests.swift` (create)

**Step 1: Write the failing tests**

```swift
// ESVBibleTests/ClosedTabsStackTests.swift
import XCTest
@testable import ESVBible

final class ClosedTabsStackTests: XCTestCase {
    var stack: ClosedTabsStack!

    override func setUp() {
        super.setUp()
        // Use a test-specific UserDefaults suite to avoid polluting real data
        stack = ClosedTabsStack(defaults: UserDefaults(suiteName: "ClosedTabsStackTests")!)
        stack.clear()
    }

    override func tearDown() {
        stack.clear()
        super.tearDown()
    }

    func testPopFromEmptyStackReturnsNil() {
        XCTAssertNil(stack.pop())
    }

    func testPushAndPop() {
        let pos = ChapterPosition(bookName: "John", chapterNumber: 3)
        stack.push(pos)
        let popped = stack.pop()
        XCTAssertEqual(popped?.bookName, "John")
        XCTAssertEqual(popped?.chapterNumber, 3)
    }

    func testPopIsLIFO() {
        stack.push(ChapterPosition(bookName: "Genesis", chapterNumber: 1))
        stack.push(ChapterPosition(bookName: "John", chapterNumber: 3))
        XCTAssertEqual(stack.pop()?.bookName, "John")
        XCTAssertEqual(stack.pop()?.bookName, "Genesis")
    }

    func testCapAt20() {
        for i in 1...25 {
            stack.push(ChapterPosition(bookName: "Psalm", chapterNumber: i))
        }
        // Should only hold 20 entries; oldest (chapters 1-5) are evicted
        var count = 0
        while stack.pop() != nil { count += 1 }
        XCTAssertEqual(count, 20)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' -only-testing:ESVBibleTests/ClosedTabsStackTests 2>&1 | tail -20`

Expected: FAIL — `ClosedTabsStack` does not exist

**Step 3: Create ClosedTabsStack.swift**

```swift
// ESVBible/ClosedTabsStack.swift
import Foundation

final class ClosedTabsStack {
    static let shared = ClosedTabsStack()

    private let key = "closedTabsStack"
    private let maxSize = 20
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func push(_ position: ChapterPosition) {
        var stack = load()
        stack.append(position)
        if stack.count > maxSize { stack.removeFirst(stack.count - maxSize) }
        save(stack)
    }

    func pop() -> ChapterPosition? {
        var stack = load()
        guard !stack.isEmpty else { return nil }
        let last = stack.removeLast()
        save(stack)
        return last
    }

    func clear() {
        save([])
    }

    private func load() -> [ChapterPosition] {
        guard let data = defaults.data(forKey: key),
              let stack = try? JSONDecoder().decode([ChapterPosition].self, from: data) else {
            return []
        }
        return stack
    }

    private func save(_ stack: [ChapterPosition]) {
        if let data = try? JSONEncoder().encode(stack) {
            defaults.set(data, forKey: key)
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' -only-testing:ESVBibleTests/ClosedTabsStackTests 2>&1 | tail -20`

Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add ESVBible/ClosedTabsStack.swift ESVBibleTests/ClosedTabsStackTests.swift
git commit -m "feat: add ClosedTabsStack for reopen-closed-tab support"
```

---

### Task 3: Update ESVBibleApp.swift

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift`

No unit tests for this task — it's pure SwiftUI scene/command wiring.

**Step 1: Switch WindowGroup to value-based form and update commands**

In `ESVBibleApp.swift`, make these four changes:

**Change 1** — Switch `WindowGroup` (lines 54–57). Replace:
```swift
        WindowGroup {
            ContentView()
        }
```
With:
```swift
        WindowGroup(for: ChapterPosition.self) { $position in
            ContentView(initialPosition: position.wrappedValue)
        }
```

**Change 2** — Remove `⌘T` from Table of Contents button (lines 80–83). Replace:
```swift
                Button("Table of Contents") {
                    NotificationCenter.default.post(name: .showTableOfContents, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
```
With:
```swift
                Button("Table of Contents") {
                    NotificationCenter.default.post(name: .showTableOfContents, object: nil)
                }
```

**Change 3** — Add `⌘T` and `⇧⌘T` commands in `CommandGroup(after: .windowArrangement)`. Replace:
```swift
            CommandGroup(after: .windowArrangement) {
                Button("Keep Window on Top") {
                    NotificationCenter.default.post(name: .toggleWindowOnTop, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
```
With:
```swift
            CommandGroup(after: .windowArrangement) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Reopen Closed Tab") {
                    NotificationCenter.default.post(name: .reopenClosedTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Keep Window on Top") {
                    NotificationCenter.default.post(name: .toggleWindowOnTop, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
```

**Change 4** — Add new `Notification.Name` entries at the bottom of the extension:
```swift
    static let newTab = Notification.Name("newTab")
    static let reopenClosedTab = Notification.Name("reopenClosedTab")
```

**Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' 2>&1 | tail -10`

Expected: `** BUILD SUCCEEDED **`

Note: The build will fail until Task 4 is done (ContentView needs the `initialPosition` parameter). If you get a "missing argument" error, that's expected — proceed to Task 4.

**Step 3: Commit**

```bash
git add ESVBible/ESVBibleApp.swift
git commit -m "feat: switch to value WindowGroup, add newTab/reopenClosedTab commands"
```

---

### Task 4: Update ContentView.swift — initialPosition and notifications

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add `initialPosition` stored property**

At the top of `ContentView`, after the `struct ContentView: View {` line, add a stored property before all the `@State` properties:

```swift
    let initialPosition: ChapterPosition?
```

This gives `ContentView` a memberwise init parameter. Since it has a `let` without a default, callers must pass it. Existing call sites that used `ContentView()` (none in the project after Task 3's change) would need updating. The only call site is now `ContentView(initialPosition: position.wrappedValue)` in `ESVBibleApp`.

**Step 2: Update onAppear to use initialPosition**

Find the `onAppear` block (around line 270). It currently reads:
```swift
        .onAppear {
            // ... key monitor setup ...
            if let pending = AppDelegate.pendingNavigation {
                AppDelegate.pendingNavigation = nil
                navigateTo(book: pending.book, chapter: pending.chapter, verseStart: pending.verse, verseEnd: pending.verse, addToHistory: true)
            } else {
                navigateTo(book: lastBook, chapter: lastChapter, verseStart: nil, verseEnd: nil, addToHistory: false)
            }
```

Replace the `if let pending` block with:
```swift
            if let initial = initialPosition {
                navigateTo(book: initial.bookName, chapter: initial.chapterNumber, verseStart: nil, verseEnd: nil, addToHistory: false)
            } else if let pending = AppDelegate.pendingNavigation {
                AppDelegate.pendingNavigation = nil
                navigateTo(book: pending.book, chapter: pending.chapter, verseStart: pending.verse, verseEnd: pending.verse, addToHistory: true)
            } else {
                navigateTo(book: lastBook, chapter: lastChapter, verseStart: nil, verseEnd: nil, addToHistory: false)
            }
```

**Step 3: Add @Environment(\.openWindow) and onDisappear**

Near the top of `ContentView` (after `@State private var isWindowOnTop`), add:
```swift
    @Environment(\.openWindow) private var openWindow
```

In `body` (or `mainContent`), add `onDisappear` alongside the existing `onAppear`:
```swift
        .onDisappear {
            if let position = visiblePosition ?? currentPosition {
                ClosedTabsStack.shared.push(position)
            }
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
```

**Step 4: Handle .newTab and .reopenClosedTab notifications**

In `body`, add two `.onReceive` handlers alongside the existing ones:
```swift
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            let position = visiblePosition ?? currentPosition ?? ChapterPosition(bookName: "Genesis", chapterNumber: 1)
            openWindow(value: position)
        }
        .onReceive(NotificationCenter.default.publisher(for: .reopenClosedTab)) { _ in
            if let position = ClosedTabsStack.shared.pop() {
                openWindow(value: position)
            }
        }
```

**Step 5: Build to verify it compiles**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' 2>&1 | tail -10`

Expected: `** BUILD SUCCEEDED **`

**Step 6: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: handle newTab/reopenClosedTab, push position onDisappear"
```

---

### Task 5: Update shortcuts overlay

**Files:**
- Modify: `ESVBible/ContentView.swift` (the `shortcutItems` array, around line 542)

**Step 1: Update the shortcutItems array**

Find `private var shortcutItems` and replace its contents:

```swift
    private var shortcutItems: [(action: String, keys: String)] {
        [
            ("Search for Passage", "\u{2318}F"),
            ("Table of Contents", "\u{2318}T"),  // remove this line
            ("Toggle History", "\u{2318}Y"),
            ("Toggle Notes", "\u{2318}N"),
            ("Previous Chapter", "\u{2318}["),
            ("Next Chapter", "\u{2318}]"),
            ("Toggle Bookmark", "\u{2318}B"),
            ("Previous Bookmark", "\u{21E7}\u{2318}\u{2190}"),
            ("Next Bookmark", "\u{21E7}\u{2318}\u{2192}"),
            ("Previous Highlight", "\u{2318}{"),
            ("Next Highlight", "\u{2318}}"),
            ("New Tab", "\u{2318}T"),
            ("Reopen Closed Tab", "\u{21E7}\u{2318}T"),
            ("Keep Window on Top", "\u{21E7}\u{2318}P"),
            ("Check for Updates", "\u{21E7}\u{2318}U"),
            ("Show Shortcuts", "?"),
            ("Dismiss", "Esc"),
        ]
    }
```

That is: remove the `("Table of Contents", "\u{2318}T")` line and add `("New Tab", "\u{2318}T")` and `("Reopen Closed Tab", "\u{21E7}\u{2318}T")` in its place (positioned logically near the bottom with the other window commands).

**Step 2: Run all tests**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -destination 'platform=macOS' 2>&1 | tail -20`

Expected: All tests PASS

**Step 3: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: update shortcuts overlay — replace ToC ⌘T with New Tab and Reopen Closed Tab"
```
