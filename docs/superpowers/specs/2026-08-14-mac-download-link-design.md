# Mac Download Link in the Web Reader

Date: 2026-08-14

The web reader at jonyen.com/zephyr never mentions that a macOS app exists. Someone reading in a
browser on a Mac has no way to find the native version short of guessing at the GitHub repo.

This adds one line to the settings popover, shown only to macOS visitors, linking straight to the
current DMG.

## Where the version comes from

The release workflow already publishes an update feed to `jonyen.com/zephyr-updates/manifest.json`
for the macOS app's own updater:

```json
{
  "version": "0.9.9",
  "notes": "…",
  "zipURL":  "https://jonyen.com/zephyr-updates/Zephyr-0.9.9.app.zip",
  "dmgURL":  "https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg",
  "signature": "…",
  "publishedAt": "2026-07-31T15:11:22Z"
}
```

The web app reads that same file. It is same-origin, ~300 bytes, and republished by every release,
so the link tracks releases with nothing to bump by hand. Only `version` and `dmgURL` are used; the
signature and notes are the updater's business.

The path is root-relative — `/zephyr-updates/manifest.json`, **not** `BASE_URL`-relative. The feed is
a sibling of `public/zephyr/`, not inside it, because the web deploy publishes `public/zephyr/` with
`keep_files: false` and would otherwise wipe the feed on every run.

## `web/src/lib/mac-download.ts`

Two functions, no React, both testable on their own.

```ts
export function isMacDesktop(nav?: Navigator): boolean
export function loadMacRelease(): Promise<MacRelease | null>   // { version, dmgURL }
```

`isMacDesktop` reads `navigator.userAgentData?.platform` first, falls back to `navigator.platform`,
then to the UA string, and requires `maxTouchPoints === 0`. The touch check is the part that
matters: iPadOS reports itself as a Mac in Safari's desktop mode, and an iPad cannot open a DMG.

`loadMacRelease` returns `null` — never throws, never rejects — on every failure mode: network
error, non-2xx, malformed JSON, or a manifest missing `dmgURL`. The link is a nicety; silence beats
a broken link. It memoizes the in-flight promise at module level, the same pattern `bible-data.ts`
uses for books, so reopening settings does not refetch. A `_resetCacheForTests` export mirrors that
module's convention.

## `web/src/components/MacDownloadLink.tsx`

Its own file, following the one-component-per-file convention in `components/`.

It returns `null` before doing anything when `!isMacDesktop()`, so non-Mac visitors never issue the
request. Otherwise it calls `loadMacRelease()` in an effect on mount and renders `null` until it
resolves — and forever, if it resolves to `null`. On success:

```
 Also for Mac — Download 0.9.9    →  /zephyr-updates/Zephyr-0.9.9.dmg
```

A plain anchor with `download`. Same-origin, so the attribute is honored; GitHub Pages serves `.dmg`
as `application/octet-stream` and would download regardless.

Because the popover mounts only when opened, the fetch happens on first open rather than page load —
the reader's startup path is untouched.

## `web/src/components/SettingsPopover.tsx`

One line, between the toggles group and the ESV attribution:

```
┌─ Settings ─────────────────────┐
│ Theme    [system][light][dark] │
│ Font     [Georgia][Palatino]   │
│ ☐ Red letter  ☐ Bionic reading │
│                                │
│  Also for Mac — Download 0.9.9 │  ← new
│                                │
│ Scripture quotations are from… │
└────────────────────────────────┘
```

## `web/src/styles/global.css`

One rule, `.mac-download`, matching `.esv-attribution`'s muted 11px system-font treatment with
`--accent` for the link color so it reads as clickable in all five themes.

## Tests

`web/src/lib/mac-download.test.ts`, vitest with `vi.stubGlobal('fetch')` as in `bible-data.test.ts`:

- `isMacDesktop` — true for a macOS desktop UA; false for Windows, for iPhone, and for a Mac-reporting
  platform with `maxTouchPoints > 0` (the iPad case)
- `loadMacRelease` — parses a good manifest; returns `null` on `!ok`, on a thrown fetch, and on a
  manifest missing `dmgURL`; memoizes across calls

## Known consequence: absent in local dev

`/zephyr-updates/` exists only on jonyen.com. Under `npm run dev` the fetch 404s and the line hides.
That is the chosen failure behavior working as designed, not a bug, and the component carries a
comment saying so.

## Out of scope

No first-visit banner, no corner button, no download counter. The reader is deliberately
distraction-free; this stays in settings.
