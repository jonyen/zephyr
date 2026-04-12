# Flag Text Issues From Reader — Design

**Status:** Approved
**Date:** 2026-04-12
**Author:** Jonathan Yen (with Claude)

## Problem

While reading in Zephyr, the author notices display/rendering bugs in the Bible text — weird spacing, broken verse numbers, wrong formatting, layout glitches. Today, capturing those means context-switching to GitHub, navigating to the repo, opening a new issue, and retyping the location. By the time that's done, the reading flow is broken and the detail is often forgotten.

## Goal

Let the user flag a text-rendering issue from inside the reader with one click and (optionally) one sentence of explanation, and have a GitHub issue filed automatically on `jonyen/zephyr`. Leverage the existing highlights feature so the flag itself is also a persistent visual marker.

## Non-goals

- Flagging general app/UX bugs unrelated to a specific verse. (Scope is bugs in rendered Bible text, anchored to a selection.)
- A public bug-reporting flow for end users of the distributed app. The feature is dev-only by default; a browser fallback covers the "no token configured" case without requiring any auth inside the app.
- Editing or deleting filed issues from inside the app.
- Batch triage / review / sync of previously-flagged issues.

## User experience

1. User selects text in `SelectableTextView`. The existing selection popover appears with color swatches.
2. Palette now includes a new **flag** color (distinct reddish-pink). Picking it:
   - Adds a `.flag`-colored highlight via `HighlightManager.addHighlight(…)` (persistent visual marker).
   - Presents `FlagIssueSheet` as a sheet over the reader.
3. `FlagIssueSheet` shows:
   - The location (e.g., `John 3:16`) as a header.
   - The selected text in a read-only quote block.
   - A single `TextField` labeled "What's wrong?" (focused on appear; empty allowed).
   - `Cancel` and `Submit` buttons. `⌘↵` submits, `Esc` cancels.
4. On Submit:
   - **If a token is configured:** `IssueReporterService` POSTs to GitHub. Toast shows `Filed issue #123`. Sheet closes.
   - **If no token, or API call fails:** Open the prefilled GitHub new-issue URL in the default browser via `NSWorkspace.shared.open(_:)`. A toast explains the fallback when it's due to failure (offline / bad token / etc.). Sheet closes.
5. Tapping the flag color on an already-flagged range **removes** the highlight (mirrors existing toggle semantics for other colors) and does **not** open the composer — prevents accidental duplicate issues.

## Architecture

Three new units, each with one clear purpose:

### 1. `IssueReporterService` (new, `ESVBible/Services/IssueReporterService.swift`)

- `@Observable` class, patterned on `UpdateService`.
- Constants: `repoOwner = "jonyen"`, `repoName = "zephyr"`.
- Reads the token on demand from `KeychainTokenStore`. Does not cache it.
- Public API:
  - `var isConfigured: Bool` — true iff a non-empty token exists in Keychain.
  - `func createIssue(report: IssueReport) async -> Result<Int, IssueReporterError>` — returns the created issue number on success.
  - `func fallbackURL(report: IssueReport) -> URL` — builds the prefilled `https://github.com/jonyen/zephyr/issues/new?title=…&body=…&labels=text-report` URL used by the browser fallback.
  - `func testConnection() async -> Result<Void, IssueReporterError>` — `GET /repos/jonyen/zephyr` using the configured token, used by the Settings "Test connection" button. Never creates an issue.
- `IssueReport` is a plain struct: `{ book, chapter, verse, selectedText, userNote, appVersion, osVersion, timestamp }`.
- `IssueReporterError` enum: `.notConfigured`, `.network(Error)`, `.unauthorized`, `.rateLimited`, `.httpStatus(Int)`, `.decoding`.
- Uses `URLSession.shared` with an injectable `URLSession` parameter for tests.
- Headers: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`.
- POST body: `{ "title": …, "body": …, "labels": ["text-report"] }`.

### 2. `KeychainTokenStore` (new, `ESVBible/Services/KeychainTokenStore.swift`)

- Thin wrapper around `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`.
- Fixed service name: `com.jonyen.zephyr.github-token`.
- Single account (we only store one token).
- Public API:
  - `static func read() -> String?`
  - `static func write(_ token: String) throws`
  - `static func delete() throws`
- Injectable service name via an internal init for tests (see testing section).

### 3. `FlagIssueSheet` (new, `ESVBible/Views/FlagIssueSheet.swift`)

- SwiftUI `View` presented via `.sheet(isPresented:)` from `ReadingPaneView` (or whichever view owns the highlight-color selection — to be confirmed during implementation).
- Takes an `IssueReport` (selection + metadata already filled in) and a closure to call on submit/cancel.
- Owns the `@State` for the `userNote` field and submit-in-flight spinner.
- Calls `IssueReporterService.createIssue(...)`. On success, calls a completion closure with the issue number. On failure, calls a completion closure with an error; view layer decides what toast to show.

### Integration with existing code

- `HighlightColor` enum (in `BibleModels.swift` or wherever it currently lives) gains a new `.flag` case. Color assignment uses a distinct hue not currently used by existing colors.
- `SelectableTextView`'s color-picker handler gains one branch: after calling `addHighlight` with `.flag`, it triggers presentation of `FlagIssueSheet` (via a binding or callback surfaced up to the view owning the sheet state).
- `HighlightManager` itself is untouched. A flag-highlight is just a highlight with a different color; existing persistence, toggle, and filter logic apply unchanged.

### New Settings pane

- Add a "GitHub" tab/section to the existing Settings window.
- One `SecureField` bound to a temporary `@State` string; a Save button writes to `KeychainTokenStore`.
- Help text: "Fine-grained personal access token scoped to `jonyen/zephyr` with *Issues: Read and write* permission." Plus a link to GitHub's new-token page.
- "Test connection" button → `IssueReporterService.testConnection()`; shows ✓ "Connected" or an error message.
- "Clear token" button → `KeychainTokenStore.delete()`.

## Data flow

```
user selects text in SelectableTextView
  → selection popover shown with color palette (incl. .flag)
  → user picks .flag
     → HighlightManager.addHighlight(book, chapter, verse, range, color: .flag)
     → FlagIssueSheet presented, prefilled with IssueReport(selectionText, location, app/OS version, now())
  → user types optional note, taps Submit
     → if IssueReporterService.isConfigured:
          → POST /repos/jonyen/zephyr/issues
          → on success: toast "Filed issue #N", sheet closes
          → on failure: NSWorkspace.open(fallbackURL), toast explains fallback, sheet closes
       else:
          → NSWorkspace.open(fallbackURL), sheet closes
```

The flag highlight is never rolled back regardless of submission outcome.

## Issue payload format

**Title (with note):** `[text] John 3:16 — <first 50 chars of userNote, trimmed>`
**Title (no note):** `[text] John 3:16`

**Body:**
```markdown
**Location:** John 3:16
**Selected text:**
> For God so loved the world, that he gave his only Son…

**What's wrong:**
<userNote, or "(no note)">

---
<sub>Zephyr 0.9.6 · macOS 15.2 · 2026-04-12T15:42:00Z</sub>
```

**Label:** `text-report` (applied via the API's `labels` field, or appended as `&labels=text-report` on the fallback URL).

Markdown special characters in the selected text are escaped so they don't break the quote block (specifically: backslash-escape `>` at the start of lines, preserve line breaks).

## Error handling

| Condition | Behavior |
|---|---|
| Token not configured (`isConfigured == false`) | Skip API call. Open prefilled GitHub new-issue URL in browser. Sheet closes. |
| Network offline / URLSession error | Toast: "Couldn't reach GitHub — opened in browser instead." Browser fallback. |
| 401 Unauthorized | Toast: "Token rejected — check Settings → GitHub." Browser fallback. |
| 403 / rate limited | Toast: "GitHub rate limited — opened in browser instead." Browser fallback. |
| Other 4xx / 5xx | Toast: `GitHub error (<status>) — opened in browser.` Browser fallback. |
| Success | Toast: `Filed issue #<number>.` Sheet closes. |

Principles:
- **Flag highlight is never rolled back on failure.** The user's visual marker of "I flagged this" is independent of whether the network round-trip succeeded.
- **Every failure has a fallback path.** Nothing is silently dropped. The worst case is one extra click in the browser.
- **No retries inside the app.** A failed API call falls straight to the browser instead — the user can always retry manually from there.

## Distribution / other users

The feature is hidden-but-reachable for users without a token:

- The flag color is always available in the palette. (Not hidden — that would require per-user state checks in the selection popover, and the feature is trivial to leave in place.)
- Picking it on an unflagged range creates a highlight and opens the composer. Toggle semantics (re-tap removes without opening) still apply.
- Without a token configured, Submit always takes the browser fallback path. End users can still file issues, they just do it through their browser. No auth in the app.
- There is no bundled/shared token. Explicitly rejected — tokens in binaries are extractable.

## Testing

**Unit tests (added):**

- `IssueReporterServiceTests`
  - Inject a stub `URLSession` via `URLProtocol`.
  - Verify POST URL, headers, and JSON body for a known `IssueReport`.
  - Verify `labels: ["text-report"]` is always present.
  - Verify success → returns issue number from parsed response.
  - Verify 401 → `.unauthorized`; 403 → `.rateLimited`; 500 → `.httpStatus(500)`; URLError → `.network`.
  - Verify `fallbackURL(report:)` produces a correctly percent-encoded URL with title, body, and labels query params.
  - Verify `testConnection()` uses GET (not POST) and never creates an issue.

- `KeychainTokenStoreTests`
  - Round-trip write → read → delete, using a test-specific service name so real Keychain entries are untouched. Clean up in `tearDown`.

- `IssueBodyFormatterTests` (pure function, no I/O)
  - Title truncation at 50 chars with ellipsis.
  - Title without note.
  - Markdown escaping for `>` in selected text.
  - Metadata footer format.

- `HighlightManagerTests` — add one case asserting a `.flag`-colored highlight round-trips through JSON encode/decode.

**Not automatically tested (manual verification required before merge):**
- The `SelectableTextView` popover correctly routes `.flag` selections to the sheet presentation.
- `FlagIssueSheet` appearance, focus-on-open, `⌘↵` / `Esc` keybindings, and Submit-in-flight state.
- Settings pane: token save, test connection, clear button.
- Browser fallback actually opens GitHub's new-issue page with correct prefill.

## Open questions (to resolve during implementation)

- Exact reddish-pink shade for `.flag` that reads clearly against both light and dark themes without colliding with any existing highlight color.
- Which view owns the `FlagIssueSheet` sheet state — likely `ReadingPaneView` since it already owns reading-area UI, but confirm during implementation.
- Whether the Settings window already has a tab container we can extend, or whether this is the first multi-tab settings surface. If the latter, use a simple `TabView`; don't over-engineer.
