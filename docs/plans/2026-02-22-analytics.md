# Analytics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add opt-in, privacy-preserving analytics to Zephyr using TelemetryDeck to track active users and feature usage.

**Architecture:** A singleton `AnalyticsService` wraps TelemetryDeck and gates all signals on an `@AppStorage("analyticsOptIn")` flag. A first-launch consent sheet and a Settings toggle let users opt in or out. Events are instrumented at the call sites in ContentView, HighlightManager, and SearchService.

**Tech Stack:** TelemetryDeck Swift SDK (SPM), SwiftUI, @AppStorage, NSSetUncaughtExceptionHandler

---

## Prerequisites

Before starting:
1. Sign up at https://dashboard.telemetrydeck.com
2. Create a new App and copy the **App ID** (a UUID string)
3. Keep it handy — it goes into `AnalyticsService.swift`

---

### Task 1: Add TelemetryDeck Swift SDK

**Files:**
- Modify: `Zephyr.xcodeproj` (via Xcode UI)

**Step 1: Open the project in Xcode**

```bash
open /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj
```

**Step 2: Add the package**

In Xcode: File → Add Package Dependencies…
- Enter URL: `https://github.com/TelemetryDeck/SwiftSDK`
- Version rule: Up to Next Major, starting from `2.0.0`
- Add to target: **ESVBible**
- Click Add Package

**Step 3: Verify the package appears**

In Xcode's Project Navigator, under Package Dependencies, you should see `TelemetryDeck`.

**Step 4: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add Zephyr.xcodeproj
git commit -m "chore: add TelemetryDeck Swift SDK via SPM"
```

---

### Task 2: Create AnalyticsService.swift

**Files:**
- Create: `ESVBible/Services/AnalyticsService.swift`
- Create: `ESVBibleTests/AnalyticsServiceTests.swift`

**Step 1: Write the failing test**

Create `ESVBibleTests/AnalyticsServiceTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class AnalyticsServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear the opt-in flag before each test
        UserDefaults.standard.removeObject(forKey: "analyticsOptIn")
    }

    func testTrackDoesNothingWhenOptedOut() {
        var signalFired = false
        let service = AnalyticsService.makeTestInstance {
            signalFired = true
        }
        service.track("testEvent")
        XCTAssertFalse(signalFired, "Should not fire signal when user has not opted in")
    }

    func testTrackDoesNothingWhenExplicitlyDeclined() {
        UserDefaults.standard.set(false, forKey: "analyticsOptIn")
        var signalFired = false
        let service = AnalyticsService.makeTestInstance {
            signalFired = true
        }
        service.track("testEvent")
        XCTAssertFalse(signalFired, "Should not fire signal when user declined")
    }

    func testTrackFiresWhenOptedIn() {
        UserDefaults.standard.set(true, forKey: "analyticsOptIn")
        var firedEvent: String?
        let service = AnalyticsService.makeTestInstance { event, _ in
            firedEvent = event
        }
        service.track("appLaunched")
        XCTAssertEqual(firedEvent, "appLaunched")
    }

    func testIsOptedInReturnsFalseByDefault() {
        let service = AnalyticsService.makeTestInstance()
        XCTAssertFalse(service.isOptedIn)
    }

    func testIsOptedInReturnsTrueAfterConsent() {
        UserDefaults.standard.set(true, forKey: "analyticsOptIn")
        let service = AnalyticsService.makeTestInstance()
        XCTAssertTrue(service.isOptedIn)
    }
}
```

**Step 2: Run the test to verify it fails**

In Xcode: Product → Test (⌘U), or:
```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj \
  -scheme ESVBible -destination 'platform=macOS' \
  -only-testing ESVBibleTests/AnalyticsServiceTests 2>&1 | tail -20
```
Expected: Compile error — `AnalyticsService` not found.

**Step 3: Create AnalyticsService.swift**

Create `ESVBible/Services/AnalyticsService.swift`:

```swift
import Foundation
import TelemetryDeck

final class AnalyticsService {

    // MARK: - Singleton
    static let shared = AnalyticsService()

    // MARK: - Internal: injected sender for testing
    // nil = use TelemetryDeck; set in tests via makeTestInstance
    var _testSender: ((String, [String: String]) -> Void)?

    private init() {}

    // MARK: - Public API

    var isOptedIn: Bool {
        UserDefaults.standard.object(forKey: "analyticsOptIn") as? Bool == true
    }

    /// Call once at app startup to configure TelemetryDeck.
    func initialize() {
        let config = TelemetryDeck.Config(appID: "YOUR-TELEMETRYDECK-APP-ID")
        TelemetryDeck.initialize(config: config)
    }

    /// Send an analytics signal. No-ops if user has not opted in.
    func track(_ event: String, parameters: [String: String] = [:]) {
        guard isOptedIn else { return }
        if let sender = _testSender {
            sender(event, parameters)
        } else {
            TelemetryDeck.signal(event, parameters: parameters)
        }
    }

    // MARK: - Test helpers

    static func makeTestInstance(sender: ((String, [String: String]) -> Void)? = nil) -> AnalyticsService {
        let instance = AnalyticsService()
        instance._testSender = sender
        return instance
    }

    // Convenience overload for tests that only care whether signal fired
    static func makeTestInstance(sender: (() -> Void)?) -> AnalyticsService {
        return makeTestInstance { _, _ in sender?() }
    }
}
```

> **Important:** Replace `"YOUR-TELEMETRYDECK-APP-ID"` with your actual App ID from the TelemetryDeck dashboard.

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj \
  -scheme ESVBible -destination 'platform=macOS' \
  -only-testing ESVBibleTests/AnalyticsServiceTests 2>&1 | tail -20
```
Expected: All 5 tests PASS.

**Step 5: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/Services/AnalyticsService.swift ESVBibleTests/AnalyticsServiceTests.swift
git commit -m "feat: add AnalyticsService with opt-in gating"
```

---

### Task 3: Initialize TelemetryDeck in ESVBibleApp.swift

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift`

**Step 1: Read the current file**

Read `ESVBible/ESVBibleApp.swift` — find the `init()` method inside `ESVBibleApp`.

**Step 2: Add AnalyticsService initialization and crash handler**

In the `ESVBibleApp.init()` body, after `SpotlightIndexer.indexIfNeeded()`, add:

```swift
// Analytics
AnalyticsService.shared.initialize()
AnalyticsService.shared.track("appLaunched")

// Crash reporting (opt-in only — AnalyticsService.shared.track handles the gate)
NSSetUncaughtExceptionHandler { exception in
    AnalyticsService.shared.track(
        "crashReported",
        parameters: ["exceptionName": exception.name.rawValue]
    )
}
```

**Step 3: Build to verify it compiles**

In Xcode: Product → Build (⌘B)
Expected: Build succeeds with no errors.

**Step 4: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/ESVBibleApp.swift
git commit -m "feat: initialize TelemetryDeck and register crash handler at startup"
```

---

### Task 4: Create AnalyticsConsentView.swift

**Files:**
- Create: `ESVBible/Views/AnalyticsConsentView.swift`

**Step 1: Create the view**

Create `ESVBible/Views/AnalyticsConsentView.swift`:

```swift
import SwiftUI

struct AnalyticsConsentView: View {
    @AppStorage("analyticsOptIn") private var analyticsOptIn: Bool?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Help Improve Zephyr")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Share anonymous usage data to help us understand how Zephyr is used. No personal information, verse content, or notes are ever collected.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Powered by [TelemetryDeck](https://telemetrydeck.com/privacy) — privacy-first analytics.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("No Thanks") {
                    analyticsOptIn = false
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Enable Analytics") {
                    analyticsOptIn = true
                    AnalyticsService.shared.track("appLaunched") // Send first signal
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 380)
    }
}
```

**Step 2: Build to verify it compiles**

In Xcode: Product → Build (⌘B)
Expected: No errors.

**Step 3: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/Views/AnalyticsConsentView.swift
git commit -m "feat: add AnalyticsConsentView first-launch consent sheet"
```

---

### Task 5: Show consent sheet in ContentView.swift

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Read ContentView.swift**

Read `ESVBible/ContentView.swift` — find where `@AppStorage` properties are declared and where `.onAppear` is used.

**Step 2: Add the opt-in state property**

In the `@AppStorage` block (near `lastBook`, `lastChapter`, `readingTheme`), add:

```swift
@AppStorage("analyticsOptIn") private var analyticsOptIn: Bool?
@State private var showAnalyticsConsent = false
```

**Step 3: Add the sheet modifier**

Find the outermost view modifier chain in `ContentView.body`. Add after existing `.sheet` or `.onAppear` modifiers:

```swift
.sheet(isPresented: $showAnalyticsConsent) {
    AnalyticsConsentView()
}
.onAppear {
    if analyticsOptIn == nil {
        // Delay slightly so the main window is fully loaded first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showAnalyticsConsent = true
        }
    }
}
```

> Note: If there is already an `.onAppear` modifier, add the analytics block inside it rather than adding a second `.onAppear`.

**Step 4: Build to verify it compiles**

In Xcode: Product → Build (⌘B)
Expected: No errors.

**Step 5: Test manually**

1. Delete `analyticsOptIn` from UserDefaults (run the app once with `UserDefaults.standard.removeObject(forKey: "analyticsOptIn")` in init, or use the Simulator Reset)
2. Launch the app — consent sheet should appear after ~0.5s
3. Click "No Thanks" — sheet dismisses, `analyticsOptIn` is set to false
4. Relaunch — sheet should NOT appear again

**Step 6: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/ContentView.swift
git commit -m "feat: show analytics consent sheet on first launch"
```

---

### Task 6: Add Privacy section to AppearanceSettingsView.swift

**Files:**
- Modify: `ESVBible/Views/AppearanceSettingsView.swift`

**Step 1: Read AppearanceSettingsView.swift**

Read `ESVBible/Views/AppearanceSettingsView.swift` in full.

**Step 2: Add the `@AppStorage` property for analytics**

In the `@AppStorage` block at the top of the struct, add:

```swift
@AppStorage("analyticsOptIn") private var analyticsOptIn: Bool?
```

**Step 3: Add a Privacy section at the bottom of the Form**

After the last existing `Section`, add:

```swift
Section("Privacy") {
    Toggle(isOn: Binding(
        get: { analyticsOptIn == true },
        set: { analyticsOptIn = $0 }
    )) {
        VStack(alignment: .leading, spacing: 2) {
            Text("Share anonymous usage data")
            Text("Helps improve Zephyr. No personal data is collected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 4: Build and verify**

In Xcode: Product → Build (⌘B). Open Settings (⌘,) — you should see the new Privacy section with the toggle.

**Step 5: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/Views/AppearanceSettingsView.swift
git commit -m "feat: add Privacy section with analytics toggle to Settings"
```

---

### Task 7: Instrument feature events in ContentView.swift

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Read ContentView.swift**

Read `ESVBible/ContentView.swift` and find:
1. Where search is triggered (look for `searchService.search(` calls)
2. Where `readingTheme` changes (look for theme picker onChange)
3. Where `selectedFont` changes (look for font picker onChange)
4. Where `bionicReadingEnabled` changes (look for bionic toggle onChange)
5. Where `.newTab` notification is handled (look for `openTab` or `.newTab`)

**Step 2: Add tracking calls at each site**

At each location found in Step 1, add the corresponding `AnalyticsService.shared.track(...)` call:

**After search executes** (wherever `searchService.search(...)` is called with a non-empty query):
```swift
AnalyticsService.shared.track("searchPerformed")
```

**In the theme picker `.onChange`** (or wherever `readingTheme` is mutated by user action):
```swift
AnalyticsService.shared.track("themeChanged", parameters: ["theme": readingTheme.rawValue])
```

**In the font picker `.onChange`**:
```swift
AnalyticsService.shared.track("fontChanged", parameters: ["font": selectedFont])
```

**In the bionic reading toggle `.onChange`**:
```swift
AnalyticsService.shared.track("bionicReadingToggled", parameters: ["enabled": bionicReadingEnabled ? "true" : "false"])
```

**In the `.newTab` notification handler** (wherever `openTab` is called or a new window is created):
```swift
AnalyticsService.shared.track("tabOpened")
```

**Step 3: Build to verify it compiles**

In Xcode: Product → Build (⌘B)
Expected: No errors.

**Step 4: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/ContentView.swift
git commit -m "feat: instrument ContentView with analytics events"
```

---

### Task 8: Instrument HighlightManager.swift

**Files:**
- Modify: `ESVBible/Services/HighlightManager.swift`

**Step 1: Read HighlightManager.swift**

Read `ESVBible/Services/HighlightManager.swift` and find the bodies of:
- `addHighlight(...)`
- `toggleBookmark(...)`
- `addNote(...)`

**Step 2: Add tracking to each method**

In `addHighlight(...)`, after the highlight is appended to `highlights`:
```swift
AnalyticsService.shared.track("highlightAdded", parameters: ["color": color.rawValue])
```

In `toggleBookmark(...)`, in the branch where a bookmark is added (not removed):
```swift
AnalyticsService.shared.track("bookmarkAdded")
```

In `addNote(...)`, after the note is appended to `notes`:
```swift
AnalyticsService.shared.track("noteAdded")
```

**Step 3: Build to verify it compiles**

In Xcode: Product → Build (⌘B)
Expected: No errors.

**Step 4: Run all tests**

```bash
xcodebuild test -project /Users/jonyen/Projects/zephyr/Zephyr.xcodeproj \
  -scheme ESVBible -destination 'platform=macOS' 2>&1 | tail -30
```
Expected: All tests PASS (existing tests + new AnalyticsServiceTests).

**Step 5: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add ESVBible/Services/HighlightManager.swift
git commit -m "feat: instrument HighlightManager with analytics events"
```

---

### Task 9: Update README

**Files:**
- Modify: `README.md`

**Step 1: Read the README**

Read `README.md` and find the line that says "no tracking".

**Step 2: Update the privacy claim**

Find the line (around line 58):
```
Completely Free — No ads, no in-app purchases, no accounts, no tracking
```

Update it to:
```
Completely Free — No ads, no in-app purchases, no accounts. Optional anonymous analytics (opt-in only, powered by TelemetryDeck).
```

Also add a brief note in the relevant section (if there's a Features or Privacy section) such as:
```
**Privacy:** Zephyr collects no data by default. On first launch you can optionally enable anonymous usage analytics (powered by TelemetryDeck). No personal information, verse content, or notes are ever collected. You can change this at any time in Settings → Privacy.
```

**Step 3: Commit**

```bash
cd /Users/jonyen/Projects/zephyr
git add README.md
git commit -m "docs: update README to reflect opt-in analytics"
```

---

## Verification Checklist

After all tasks are complete, verify end-to-end:

- [ ] Fresh install (clear `analyticsOptIn` from UserDefaults) → consent sheet appears on launch
- [ ] Click "No Thanks" → no TelemetryDeck signals sent, `analyticsOptIn = false`
- [ ] Click "Enable Analytics" → signals appear in TelemetryDeck dashboard
- [ ] Settings → Privacy toggle → turning off stops signals immediately
- [ ] All existing tests still pass
- [ ] App builds with no warnings related to new code
