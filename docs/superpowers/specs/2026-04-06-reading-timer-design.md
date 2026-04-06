# Reading Timer — Design Spec

## Overview

A subtle reading timer that lets users set a duration and receive a gentle visual notification when time is up. The timer lives in the window's title bar area and is non-intrusive — users can continue reading after the timer finishes.

## Goals

- Let users set a reading duration from presets (5, 10, 15, 20, 30 min) or a custom value
- Show a subtle countdown in the title bar while running
- Indicate completion with a gentle color change and pulse — no modal dialogs or disruptive banners
- Timer resets on app quit (no persistence across sessions)

## Architecture

Two new files following the existing `UpdateService` / `UpdateBannerView` pattern:

- `ESVBible/Services/ReadingTimerService.swift` — `@Observable` state machine and countdown logic
- `ESVBible/Views/ReadingTimerView.swift` — title bar control, popover picker, and finished indicator

### ReadingTimerService

```swift
@Observable
class ReadingTimerService {
    enum TimerState {
        case idle
        case running(secondsRemaining: Int)
        case finished
    }

    var state: TimerState = .idle
    let presets: [Int] = [5, 10, 15, 20, 30] // minutes

    func start(minutes: Int)  // Starts countdown, transitions to .running
    func stop()               // Cancels timer, returns to .idle
    func dismiss()            // From .finished, returns to .idle
}
```

- Uses `Timer.publish(every: 1, on: .main, in: .common)` with Combine for the countdown
- Each tick decrements `secondsRemaining`; when it hits 0, transitions to `.finished`
- `stop()` cancels the timer subscription and resets to `.idle`
- No persistence — state resets to `.idle` on init

### ReadingTimerView

Positioned using `.overlay(alignment: .topTrailing)` on the main ZStack in `ContentView`, sitting in the title bar region.

**States:**

| State | Display | Interaction |
|-------|---------|-------------|
| Idle | Clock icon + "Timer" label, muted color | Click opens popover with preset picker |
| Running | Blue clock icon + "mm:ss" countdown (tabular-nums) | Click opens popover with cancel option |
| Finished | Orange "Done" label with subtle pulse animation | Click dismisses, returns to idle |

**Popover contents:**
- Section label: "Set Reading Timer"
- Preset buttons: 5m, 10m, 15m, 20m, 30m (pill-shaped, highlight on selection)
- Custom input: text field for entering custom minutes
- "Start Timer" button
- When timer is running: shows remaining time and a "Cancel" button instead

### Integration Points

**ContentView.swift:**
- Add `@State private var readingTimerService = ReadingTimerService()` property
- Add `ReadingTimerView(timerService: readingTimerService)` in the main ZStack as an overlay

**ESVBibleApp.swift:**
- Add a "Reading Timer" menu command under the text editing command group
- Posts a `.toggleReadingTimer` notification to open/close the popover
- Add keyboard shortcut (suggestion: `Cmd+Shift+T` or similar — verify no conflict)

**Notification.Name extension:**
- Add `.toggleReadingTimer` notification name

## UI Details

- Title bar control uses `.background(.regularMaterial)` or subtle background matching the existing UI
- Countdown uses `font(.system(.caption, design: .monospaced))` with `.monospacedDigit()` for stable width
- Finished pulse animation: opacity oscillates between 1.0 and 0.6 over 2 seconds, repeating
- Orange accent color (#FF9500) for finished state, blue (#007AFF) for running state
- Popover uses native SwiftUI `.popover()` modifier

## Out of Scope

- Timer persistence across app sessions
- Multiple concurrent timers
- Sound notifications
- Timer history or statistics
- Integration with reading progress tracking
