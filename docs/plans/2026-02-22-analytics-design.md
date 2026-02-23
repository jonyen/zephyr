# Analytics Design — Zephyr

**Date:** 2026-02-22
**Status:** Approved

## Goal

Add opt-in, privacy-preserving analytics to track active users and feature usage, while maintaining Zephyr's "no tracking" privacy positioning.

## Approach

Use [TelemetryDeck](https://telemetrydeck.com) — a privacy-first analytics service built for Swift/Apple apps. It cryptographically hashes all identifiers server-side so no PII is ever stored. No backend required. Free tier available.

## Architecture

**Dependency:** `TelemetryDeck-Swift` added via Swift Package Manager.

**`AnalyticsService.swift`** — a singleton that:
- Wraps `TelemetryManager` from the TelemetryDeck SDK
- Checks `@AppStorage("analyticsOptIn")` before sending any signal
- Exposes `track(_ event: String, parameters: [String: String] = [:])`
- Initialized once in `ZephyrApp.init()`

App version and OS version are attached automatically by the SDK.

## Events

| Event | Trigger |
|---|---|
| `appLaunched` | App starts (drives DAU/MAU) |
| `searchPerformed` | User runs a Bible search |
| `bookmarkAdded` | User adds a bookmark |
| `highlightAdded` | User highlights a verse |
| `noteAdded` | User saves a note |
| `themeChanged` | User changes reading theme |
| `fontChanged` | User changes font |
| `bionicReadingToggled` | User toggles bionic reading |
| `tabOpened` | User opens a new tab |
| `crashReported` | Uncaught exception handler fires |

No user-written content, no verse text, no device identifiers are sent.

## Opt-in UX

**First launch consent sheet:**
- Shown once when `analyticsOptIn` has never been set (stored as `Bool?`, nil = undecided)
- Brief explanation + link to TelemetryDeck privacy policy
- Buttons: "Enable Analytics" / "No Thanks"

**Settings toggle:**
- New "Privacy" section in the existing Settings panel
- Toggle: "Share anonymous usage data" with description "Helps improve Zephyr. No personal data is collected."
- Toggling off immediately stops all future signals

**Crash reporting:**
- Registered via `NSSetUncaughtExceptionHandler` at startup
- Only active if opted in
- Sends exception name only (no stack traces — could contain user data)

## Files Affected

- `Zephyr.xcodeproj` — add TelemetryDeck SPM package
- `ZephyrApp.swift` — initialize AnalyticsService, register crash handler
- `AnalyticsService.swift` — new file, analytics singleton
- `AnalyticsConsentView.swift` — new file, first-launch consent sheet
- `ContentView.swift` — trigger consent sheet on first launch
- `AppearanceSettingsView.swift` (or new `PrivacySettingsView.swift`) — add Privacy section with toggle
- Key service files — instrument with `AnalyticsService.shared.track(...)` calls:
  - `SearchService.swift`
  - `HighlightManager.swift`
  - `HistoryManager.swift` (or relevant bookmark/tab files)

## Privacy

- README updated to reflect opt-in analytics (preserves "no tracking by default" stance)
- "No tracking" claim remains accurate for users who decline or ignore the prompt
