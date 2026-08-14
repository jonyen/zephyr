# Mac Download Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show macOS visitors to jonyen.com/zephyr a one-line link in the settings popover that downloads the current Zephyr DMG.

**Architecture:** All logic — platform detection and manifest fetching — lives in a plain TypeScript module (`web/src/lib/mac-download.ts`) that is fully unit-tested. A thin React component (`web/src/components/MacDownloadLink.tsx`) renders one anchor from it and is dropped into the existing settings popover. The version and URL come from `/zephyr-updates/manifest.json`, the update feed the macOS app's own updater already reads, so the link tracks releases with nothing to bump by hand.

**Tech Stack:** React 19, TypeScript ~6.0, Vite 8, Vitest 4 (jsdom), plain CSS. **No new dependencies.**

## Global Constraints

- **No new npm dependencies.** Everything here is React + `fetch` + CSS.
- **Manifest URL is exactly `/zephyr-updates/manifest.json`** — root-relative, *not* `import.meta.env.BASE_URL`-relative. The feed is a sibling of the app's deployed directory (`public/zephyr-updates/` vs `public/zephyr/`), because the web deploy publishes `public/zephyr/` with `keep_files: false` and would otherwise wipe the feed.
- **Link copy is exactly `Also for Mac — Download {version}`** — em dash (—, U+2014), not a hyphen.
- **Every failure renders nothing.** `loadMacRelease` never throws and never rejects; the component renders `null`. A broken or absent link is worse than no link.
- **Non-Mac visitors must never issue the fetch.** Detection gates the request, not just the render.
- **This codebase has no component tests.** All existing tests are in `src/lib/` and `src/state/`. Do not add a testing pattern that does not exist here — keep logic in the lib, where it is tested, and keep the component thin enough that typecheck plus a visual check is adequate.
- **Follow existing file conventions:** one component per file in `src/components/`, default export, no CSS-in-JS (all styles in `src/styles/global.css`).

---

### Task 1: Platform detection and manifest loading

The whole logic layer, test-first. Ends with a fully tested module that the component in Task 2 just renders.

**Files:**
- Create: `web/src/lib/mac-download.ts`
- Test: `web/src/lib/mac-download.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, relied on by Task 2:
  - `export interface MacRelease { version: string; dmgURL: string }`
  - `export function isMacDesktop(nav?: NavigatorLike): boolean`
  - `export function loadMacRelease(): Promise<MacRelease | null>`
  - `export function _resetCacheForTests(): void`

- [ ] **Step 1: Write the failing test**

Create `web/src/lib/mac-download.test.ts`. This mirrors `web/src/lib/bible-data.test.ts`, which stubs `fetch` with `vi.stubGlobal` — read that file first if the pattern is unfamiliar.

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { isMacDesktop, loadMacRelease, _resetCacheForTests } from './mac-download'

// A real manifest, copied from https://jonyen.com/zephyr-updates/manifest.json.
// Only version and dmgURL are consumed; the rest is the macOS updater's business.
const MANIFEST = {
  version: '0.9.9',
  notes: '## What’s New\n\n* Enhanced update security.',
  zipURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.app.zip',
  dmgURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg',
  signature: 'iWdBBG9VduLesHSmrPfBd+h5USwOihIamNPk29QRtjZDjP3nHkffXZvHSqMTyTa5o/1/uFXZrjJeA7oZ6wR/Bw==',
  publishedAt: '2026-07-31T15:11:22Z',
}

const MAC = { platform: 'MacIntel', maxTouchPoints: 0 }
const MAC_VIA_UA_DATA = { userAgentData: { platform: 'macOS' }, platform: '', maxTouchPoints: 0 }
const WINDOWS = { platform: 'Win32', maxTouchPoints: 0 }
const IPHONE = { platform: 'iPhone', userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)', maxTouchPoints: 5 }
// Safari's desktop mode on iPadOS reports MacIntel. It cannot open a DMG.
const IPAD_IN_DESKTOP_MODE = { platform: 'MacIntel', maxTouchPoints: 5 }

const okResponse = (body: unknown) => vi.fn(async () => ({ ok: true, json: async () => body }))

beforeEach(() => {
  _resetCacheForTests()
  vi.unstubAllGlobals()
})

describe('isMacDesktop', () => {
  it('is true for a Mac desktop', () => {
    expect(isMacDesktop(MAC)).toBe(true)
  })
  it('is true when only userAgentData.platform is present', () => {
    expect(isMacDesktop(MAC_VIA_UA_DATA)).toBe(true)
  })
  it('is false on Windows', () => {
    expect(isMacDesktop(WINDOWS)).toBe(false)
  })
  it('is false on iPhone', () => {
    expect(isMacDesktop(IPHONE)).toBe(false)
  })
  it('is false on an iPad reporting itself as a Mac', () => {
    expect(isMacDesktop(IPAD_IN_DESKTOP_MODE)).toBe(false)
  })
})

describe('loadMacRelease', () => {
  it('returns version and dmgURL from the manifest', async () => {
    vi.stubGlobal('fetch', okResponse(MANIFEST))
    expect(await loadMacRelease()).toEqual({
      version: '0.9.9',
      dmgURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg',
    })
    expect(fetch).toHaveBeenCalledWith('/zephyr-updates/manifest.json')
  })

  it('returns null on a non-2xx response', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 404, json: async () => ({}) })))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the fetch throws', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new Error('offline') }))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the manifest has no dmgURL', async () => {
    vi.stubGlobal('fetch', okResponse({ version: '0.9.9' }))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the manifest is not an object', async () => {
    vi.stubGlobal('fetch', okResponse(null))
    expect(await loadMacRelease()).toBeNull()
  })

  it('memoizes: a second call does not refetch', async () => {
    vi.stubGlobal('fetch', okResponse(MANIFEST))
    await loadMacRelease()
    await loadMacRelease()
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd web && npx vitest run src/lib/mac-download.test.ts
```

Expected: FAIL — `Failed to resolve import "./mac-download"`. The module does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `web/src/lib/mac-download.ts`:

```ts
export interface MacRelease {
  version: string
  dmgURL: string
}

// The update feed the macOS app's own updater reads. It is a SIBLING of this app's
// deployed directory — public/zephyr-updates/ next to public/zephyr/ — so this path is
// root-relative, not BASE_URL-relative. See the release workflow's "Publish update feed"
// step. It does not exist under `npm run dev`, where this fetch 404s and the link hides.
const MANIFEST_URL = '/zephyr-updates/manifest.json'

// Structural, rather than lib.dom's Navigator, for two reasons: userAgentData is not in
// TypeScript's DOM lib yet, and tests pass plain object literals.
interface NavigatorLike {
  platform?: string
  userAgent?: string
  maxTouchPoints?: number
  userAgentData?: { platform?: string }
}

export function isMacDesktop(nav: NavigatorLike = navigator): boolean {
  // iPadOS reports itself as MacIntel in Safari's desktop mode, and cannot open a DMG.
  // No Mac desktop reports touch points, so this separates them cleanly.
  if ((nav.maxTouchPoints ?? 0) > 0) return false
  const platform = nav.userAgentData?.platform || nav.platform || nav.userAgent || ''
  return /mac/i.test(platform)
}

let cache: Promise<MacRelease | null> | null = null

export function loadMacRelease(): Promise<MacRelease | null> {
  // Deliberately not cleared on failure, unlike bible-data's loadRedLetter: a book the
  // reader needs is worth retrying, an optional download link is not.
  if (!cache) cache = fetchRelease()
  return cache
}

async function fetchRelease(): Promise<MacRelease | null> {
  try {
    const res = await fetch(MANIFEST_URL)
    if (!res.ok) return null
    const m: unknown = await res.json()
    if (typeof m !== 'object' || m === null) return null
    const { version, dmgURL } = m as Partial<MacRelease>
    if (typeof version !== 'string' || typeof dmgURL !== 'string') return null
    return { version, dmgURL }
  } catch {
    return null
  }
}

export function _resetCacheForTests(): void {
  cache = null
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd web && npx vitest run src/lib/mac-download.test.ts
```

Expected: PASS — 11 tests.

- [ ] **Step 5: Run the whole suite and the typecheck**

```bash
cd web && npm test && npm run build && npm run lint
```

Expected: all suites pass (61 tests total: the 50 that existed plus these 11), `tsc -b` clean, oxlint clean.

- [ ] **Step 6: Commit**

```bash
git add web/src/lib/mac-download.ts web/src/lib/mac-download.test.ts
git commit -m "feat(web): add Mac platform detection and release manifest loading"
```

---

### Task 2: Render the link in the settings popover

**Files:**
- Create: `web/src/components/MacDownloadLink.tsx`
- Modify: `web/src/components/SettingsPopover.tsx` (add the import; add one element between the toggles `settings-group` and the `esv-attribution` paragraph)
- Modify: `web/src/styles/global.css` (add one rule after `.esv-attribution-settings`, currently line 37)

**Interfaces:**
- Consumes, from Task 1: `isMacDesktop()`, `loadMacRelease()`, and the `MacRelease` type from `../lib/mac-download`.
- Produces: `MacDownloadLink`, a default-exported component taking no props.

- [ ] **Step 1: Write the component**

Create `web/src/components/MacDownloadLink.tsx`:

```tsx
import { useEffect, useState } from 'react'
import { isMacDesktop, loadMacRelease, type MacRelease } from '../lib/mac-download'

// One line in the settings popover pointing macOS visitors at the native app.
//
// Renders nothing unless the visitor is on a Mac desktop AND the update manifest
// loads. Note it is therefore always absent under `npm run dev` — /zephyr-updates/
// only exists on jonyen.com. That is expected, not a bug; see the plan's Step 4 for
// how to check it locally.
export default function MacDownloadLink() {
  const [release, setRelease] = useState<MacRelease | null>(null)
  const mac = isMacDesktop()

  useEffect(() => {
    // Gate the request, not just the render: nobody on Windows or a phone should
    // pay for a fetch whose result they can never see.
    if (!mac) return
    let live = true
    loadMacRelease().then((r) => { if (live) setRelease(r) })
    return () => { live = false }
  }, [mac])

  if (!mac || !release) return null
  return (
    <a className="mac-download" href={release.dmgURL} download>
      Also for Mac — Download {release.version}
    </a>
  )
}
```

- [ ] **Step 2: Add the style**

In `web/src/styles/global.css`, immediately after the `.esv-attribution-settings` rule (line 37), add:

```css
.mac-download { display: block; margin: 12px 0 0; padding: 10px 0 0; border-top: 1px solid var(--divider); color: var(--accent); font-family: -apple-system, system-ui, sans-serif; font-size: 11px; text-decoration: none; }
.mac-download:hover { text-decoration: underline; }
```

This mirrors `.esv-attribution`'s muted 11px system-font treatment but uses `var(--accent)`, which is defined in every theme block (`light`, `dark`, `sepia`, `black`), so it reads as clickable under all of them.

- [ ] **Step 3: Wire it into the popover**

In `web/src/components/SettingsPopover.tsx`, add the import beside the existing ones:

```tsx
import MacDownloadLink from './MacDownloadLink'
```

Then place the element between the closing `</div>` of the toggles `settings-group` and the ESV attribution paragraph, so this block reads:

```tsx
        <div className="settings-group">
          <label className="settings-toggle"><input type="checkbox" checked={prefs.redLetter} onChange={(e) => setPref('redLetter', e.target.checked)} /> Red letter</label>
          <label className="settings-toggle"><input type="checkbox" checked={prefs.bionic} onChange={(e) => setPref('bionic', e.target.checked)} /> Bionic reading</label>
        </div>
        <MacDownloadLink />
        <p className="esv-attribution esv-attribution-settings">
```

- [ ] **Step 4: Verify it renders, using a local stand-in manifest**

The link cannot appear in dev on its own, because `/zephyr-updates/` is not part of this app. In dev, Vite serves `web/public/` at the site root, so a scratch file at that exact path makes the real code path work end to end with no source changes:

```bash
cd web
mkdir -p public/zephyr-updates
cat > public/zephyr-updates/manifest.json <<'JSON'
{"version":"0.9.9","dmgURL":"https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg"}
JSON
npm run dev
```

Open the dev URL on a Mac, click the ⚙ button, and confirm:
- the line reads `Also for Mac — Download 0.9.9`
- it sits between the toggles and the ESV attribution
- it is legible in all four theme palettes (switch through light / dark / sepia / black in the same popover)
- clicking it downloads the DMG from jonyen.com

Then **delete the scratch file** — it must not be committed, or it would deploy a bogus manifest to `/zephyr/zephyr-updates/`:

```bash
rm -rf public/zephyr-updates
git status --short   # expect only the three intended files
```

- [ ] **Step 5: Run the suite, typecheck, and lint**

```bash
cd web && npm test && npm run build && npm run lint
```

Expected: 61 tests pass, `tsc -b` clean, oxlint clean. The typecheck is the real gate for this task — it is what catches a wrong import path or a misused `MacRelease`.

- [ ] **Step 6: Commit**

```bash
git add web/src/components/MacDownloadLink.tsx web/src/components/SettingsPopover.tsx web/src/styles/global.css
git commit -m "feat(web): offer the Mac app from the settings popover"
```

---

## Deploying

Both commits touch `web/**`, so pushing to `main` triggers `.github/workflows/deploy-web.yml`, which fetches the scripture text, builds, verifies `dist/data/` holds 67 files, and publishes into `jonyen/jonyen-website`. That repo's own Pages workflow then puts it live at jonyen.com/zephyr, usually within a couple of minutes.

After it lands, confirm on a Mac that the settings popover shows the line and the DMG downloads. On any non-Mac browser, confirm the line is absent and that no request to `/zephyr-updates/manifest.json` appears in the network panel.
