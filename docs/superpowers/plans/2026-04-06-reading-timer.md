# Reading Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a subtle reading timer to the title bar that lets users pick a duration and shows a gentle visual indicator when time is up.

**Architecture:** New `ReadingTimerService` (@Observable) handles state machine and countdown via Combine Timer. New `ReadingTimerView` renders the title bar control with popover. Integrated into `ContentView` as an overlay and `ESVBibleApp` as a menu command.

**Tech Stack:** SwiftUI, Combine, @Observable macro

**Spec:** `docs/superpowers/specs/2026-04-06-reading-timer-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `ESVBible/Services/ReadingTimerService.swift` | Create | Timer state machine, countdown logic |
| `ESVBible/Views/ReadingTimerView.swift` | Create | Title bar control, popover, finished indicator |
| `ESVBible/ContentView.swift` | Modify | Add service property, place overlay |
| `ESVBible/ESVBibleApp.swift` | Modify | Add menu command, notification name |

---

### Task 1: Create ReadingTimerService

**Files:**
- Create: `ESVBible/Services/ReadingTimerService.swift`

- [ ] **Step 1: Create ReadingTimerService with state enum and properties**

```swift
import Foundation
import Combine

@Observable
class ReadingTimerService {
    enum TimerState: Equatable {
        case idle
        case running(secondsRemaining: Int)
        case finished

        static func == (lhs: TimerState, rhs: TimerState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case let (.running(a), .running(b)): return a == b
            case (.finished, .finished): return true
            default: return false
            }
        }
    }

    private(set) var state: TimerState = .idle
    let presets: [Int] = [5, 10, 15, 20, 30]

    private var timerCancellable: AnyCancellable?

    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    var secondsRemaining: Int {
        if case let .running(seconds) = state { return seconds }
        return 0
    }

    var formattedTimeRemaining: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(minutes: Int) {
        guard minutes > 0 else { return }
        let totalSeconds = minutes * 60
        state = .running(secondsRemaining: totalSeconds)

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        state = .idle
    }

    func dismiss() {
        state = .idle
    }

    private func tick() {
        guard case let .running(seconds) = state else {
            timerCancellable?.cancel()
            timerCancellable = nil
            return
        }

        if seconds <= 1 {
            timerCancellable?.cancel()
            timerCancellable = nil
            state = .finished
        } else {
            state = .running(secondsRemaining: seconds - 1)
        }
    }
}
```

- [ ] **Step 2: Add the notification name for the reading timer**

Add to the `Notification.Name` extension at the bottom of `ESVBible/ESVBibleApp.swift`:

```swift
static let toggleReadingTimer = Notification.Name("toggleReadingTimer")
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project Zephyr.xcodeproj -scheme Zephyr build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ESVBible/Services/ReadingTimerService.swift ESVBible/ESVBibleApp.swift
git commit -m "feat: add ReadingTimerService with state machine and countdown"
```

---

### Task 2: Create ReadingTimerView

**Files:**
- Create: `ESVBible/Views/ReadingTimerView.swift`

- [ ] **Step 1: Create ReadingTimerView with all three states and popover**

```swift
import SwiftUI

struct ReadingTimerView: View {
    let timerService: ReadingTimerService
    @State private var showPopover = false
    @State private var customMinutes = ""

    var body: some View {
        timerButton
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                popoverContent
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleReadingTimer)) { _ in
                showPopover.toggle()
            }
    }

    @ViewBuilder
    private var timerButton: some View {
        switch timerService.state {
        case .idle:
            Button {
                showPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Timer")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

        case .running:
            Button {
                showPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    Text(timerService.formattedTimeRemaining)
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

        case .finished:
            Button {
                timerService.dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .opacity(1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: timerService.isFinished
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                // Trigger the pulse by the state already being .finished
            }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if timerService.isRunning {
                runningPopover
            } else {
                idlePopover
            }
        }
        .padding(16)
        .frame(width: 200)
    }

    private var idlePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Reading Timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Preset buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(timerService.presets, id: \.self) { minutes in
                    Button {
                        timerService.start(minutes: minutes)
                        showPopover = false
                    } label: {
                        Text("\(minutes)m")
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom input
            HStack(spacing: 8) {
                TextField("Min", text: $customMinutes)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 60)
                    .onSubmit { startCustomTimer() }

                Button("Start") {
                    startCustomTimer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(Int(customMinutes) == nil || Int(customMinutes)! <= 0)
            }
        }
    }

    private var runningPopover: some View {
        VStack(spacing: 12) {
            Text(timerService.formattedTimeRemaining)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .monospacedDigit()

            Text("remaining")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel Timer") {
                timerService.stop()
                showPopover = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity)
    }

    private func startCustomTimer() {
        guard let minutes = Int(customMinutes), minutes > 0 else { return }
        timerService.start(minutes: minutes)
        customMinutes = ""
        showPopover = false
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project Zephyr.xcodeproj -scheme Zephyr build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (`.toggleReadingTimer` notification name was added in Task 1)

- [ ] **Step 3: Commit**

```bash
git add ESVBible/Views/ReadingTimerView.swift
git commit -m "feat: add ReadingTimerView with popover and timer states"
```

---

### Task 3: Integrate into ContentView and ESVBibleApp

**Files:**
- Modify: `ESVBible/ContentView.swift:6` (add service property)
- Modify: `ESVBible/ContentView.swift:86-146` (add overlay in ZStack)
- Modify: `ESVBible/ESVBibleApp.swift:132` (add menu command after bookmark commands)

- [ ] **Step 1: Add menu command in ESVBibleApp.swift**

Add after the existing bookmark/highlight commands block (after line 131, before the `CommandGroup(after: .windowArrangement)` block):

```swift
Divider()

Button("Reading Timer") {
    NotificationCenter.default.post(name: .toggleReadingTimer, object: nil)
}
.keyboardShortcut("r", modifiers: [.command, .shift])
```

- [ ] **Step 2: Add ReadingTimerService property in ContentView.swift**

Add after the `@State private var updateService = UpdateService()` line (line 39):

```swift
@State private var readingTimerService = ReadingTimerService()
```

- [ ] **Step 3: Add ReadingTimerView overlay in ContentView.swift**

In `mainContent`, add the `ReadingTimerView` as an overlay on the ZStack. Add this after the `WindowAccessor` line (line 144) but still inside the ZStack:

```swift
// Reading timer in title bar area
VStack {
    HStack {
        Spacer()
        ReadingTimerView(timerService: readingTimerService)
            .padding(.trailing, 12)
            .padding(.top, 4)
    }
    Spacer()
}
```

- [ ] **Step 4: Build and run to verify everything works**

Run: `xcodebuild -project Zephyr.xcodeproj -scheme Zephyr build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ESVBible/ContentView.swift ESVBible/ESVBibleApp.swift
git commit -m "feat: integrate reading timer into ContentView and app menu"
```

---

### Task 4: Polish the finished-state pulse animation

**Files:**
- Modify: `ESVBible/Views/ReadingTimerView.swift`

The opacity-based pulse in Task 2 may not trigger properly since the value doesn't change after appearing. This task ensures the pulse animation works correctly.

- [ ] **Step 1: Update the finished state in ReadingTimerView to use a local animation state**

Replace the `.finished` case in `timerButton` with:

```swift
case .finished:
    FinishedTimerButton {
        timerService.dismiss()
    }
```

And add a new private struct at the bottom of the file (inside the same file, outside `ReadingTimerView`):

```swift
private struct FinishedTimerButton: View {
    let onDismiss: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button {
            onDismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text("Done")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .opacity(isPulsing ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
```

- [ ] **Step 2: Remove the old finished case animation code**

Remove the `.onAppear` comment block and the `.animation(...)` modifier from the old `.finished` case that was replaced.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project Zephyr.xcodeproj -scheme Zephyr build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ESVBible/Views/ReadingTimerView.swift
git commit -m "fix: use local state for finished pulse animation"
```
