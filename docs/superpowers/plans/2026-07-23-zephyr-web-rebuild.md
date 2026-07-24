# Zephyr Web Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Zephyr (native macOS ESV Bible reader) as a static Vite + React SPA in `~/Projects/zephyr-web`, replacing the previous Next.js attempt, hosted at `jonyen.com/zephyr`.

**Architecture:** Pure client-side SPA. Bible text ships as 66 per-book JSON files fetched lazily; a generated `bible-index.ts` provides navigation math with zero fetches. All user data (highlights, bookmarks, history, prefs) lives in localStorage. The reading pane is a chapter-list infinite scroller with manual scroll-anchor compensation; the scrubber is a behavior-for-behavior port of the native SwiftUI `BibleScrubber`.

**Tech Stack:** Vite 6, React 19, TypeScript, react-router-dom 7, Vitest 3 (jsdom), GitHub Pages (deployed into `jonyen.github.io/zephyr/`).

**Spec:** `docs/superpowers/specs/2026-07-23-zephyr-web-design.md` — read it before starting.

## Global Constraints

- Working directory: `/Users/jonyen/Projects/zephyr-web` (all paths relative to it).
- Vite `base` MUST be `/zephyr/` in production builds, `/` in dev.
- URL scheme: `/:bookSlug/:chapter` (e.g. `/isaiah/40`, `/1-corinthians/13`), slugs lowercase-hyphenated.
- localStorage keys MUST use the `zephyr.v1.` prefix exactly as in the spec.
- No backend, no accounts, no analytics. Do NOT reintroduce Prisma/auth/API routes.
- Old `search_index.json` (25MB) MUST NOT be shipped in `public/data/`.
- The scrubber constants come from the native source: track inset 20px, strip width 30px, thumb 6×30px, label min-gap 20px, label font 13px, opacity falloff 0.07/step floor 0.3, panel hide delay 150ms.
- TOTAL chapters = 1189 (global indices 0–1188).
- Every commit message uses conventional-commit prefixes (`feat:`, `test:`, `chore:`, `docs:`).
- After each task: run `npx vitest run` — all tests green before committing.

## File Structure

```
zephyr-web/
  index.html                      # Vite entry (title "Zephyr", theme bootstrap)
  vite.config.ts                  # base '/zephyr/' in prod, vitest config
  package.json / tsconfig*.json
  public/data/                    # 66 book JSONs + red_letter_verses.json
  scripts/generate-bible-index.mjs
  src/
    main.tsx                      # router bootstrap
    App.tsx                       # shell: Reader route, overlays, shortcuts
    styles/global.css             # themes (CSS vars), all component styles
    lib/
      types.ts                    # Book/Chapter/Verse/Position/Highlight...
      bible-index.ts              # GENERATED data (BOOKS array, TOTAL_CHAPTERS)
      bible-nav.ts                # index math, slug lookup, chapterAfter/Before
      bible-data.ts               # fetch + cache book JSONs, red letter
      reference-parser.ts         # "1 cor 13:4-7" → Position + verse range
      search.ts                   # keyword scan over loaded books
      label-spacing.ts            # min-gap forward/backward pass (native port)
      bionic.ts                   # bionic reading word segmentation
      storage.ts                  # localStorage wrapper + KEYS
    state/
      prefs.tsx                   # theme/font/redLetter/bionic context
      annotations.tsx             # highlights/bookmarks/history context
    components/
      Reader.tsx                  # route component: URL ↔ position, owns overlur state
      ReadingPane.tsx             # infinite chapter scroller
      ChapterView.tsx             # one chapter: title, drop cap, verses
      VerseText.tsx               # verse spans: red letter, highlights, bionic
      Scrubber.tsx                # right-edge strip: track/thumb/markers/drag
      ScrubberPanel.tsx           # floating 66-book label panel
      SelectionToolbar.tsx        # highlight colors popup on text selection
      SearchOverlay.tsx           # ⌘K reference + keyword search
      TocOverlay.tsx              # book grid → chapter grid
      HistoryOverlay.tsx          # recent locations
      SettingsPopover.tsx         # theme/font/toggles
      ShortcutsOverlay.tsx        # "?" cheat sheet
    hooks/
      useKeyboardShortcuts.ts
  .github/workflows/deploy.yml
```

Interface conventions used throughout (defined in Task 2, `src/lib/types.ts`):

```ts
export interface Verse { number: number; text: string }
export interface Chapter { number: number; verses: Verse[] }
export interface Book { name: string; chapters: Chapter[] }
export interface Position { book: string; chapter: number }   // book = display name, e.g. "1 Corinthians"
export type HighlightColor = 'yellow' | 'green' | 'blue' | 'pink' | 'purple'
export interface Highlight { book: string; chapter: number; verse: number; startChar: number; endChar: number; color: HighlightColor }
export interface Bookmark { book: string; chapter: number }
export interface HistoryEntry { book: string; chapter: number; timestamp: number }
export interface Prefs { theme: 'system'|'light'|'dark'|'sepia'|'black'; font: 'georgia'|'palatino'|'helvetica'; redLetter: boolean; bionic: boolean }
```

---

### Task 1: Reset repo and scaffold Vite + React + TS

**Files:**
- Delete: all Next.js app files (`src/`, `prisma/`, configs) — data preserved
- Create: Vite scaffold, `vite.config.ts`, `public/data/*.json`, `src/styles/global.css`

**Interfaces:**
- Consumes: nothing
- Produces: a building Vite app with `npm run dev`, `npm run build`, `npx vitest run` working; Bible JSONs at `public/data/`; `import.meta.env.BASE_URL` respected.

- [ ] **Step 1: Preserve the Bible data outside the tree**

```bash
cd /Users/jonyen/Projects/zephyr-web
mkdir -p ../zephyr-web-datahold
cp src/data/*.json ../zephyr-web-datahold/
```

- [ ] **Step 2: Remove the old app (git history keeps it)**

```bash
git rm -r -q src prisma public package.json package-lock.json tsconfig.json \
  next.config.ts postcss.config.mjs eslint.config.mjs next-env.d.ts prisma.config.ts README.md
git rm -q --ignore-unmatch tsconfig.tsbuildinfo dev.db .gitignore
rm -rf node_modules .next tsconfig.tsbuildinfo dev.db
git commit -m "chore: remove Next.js attempt for fresh Vite rebuild"
```

- [ ] **Step 3: Scaffold Vite into a temp dir and move it in**

```bash
npm create vite@latest tmp-scaffold -- --template react-ts
mv tmp-scaffold/.gitignore tmp-scaffold/* .
rmdir tmp-scaffold
npm install
npm install react-router-dom
npm install -D vitest jsdom @types/node
```

- [ ] **Step 4: Restore data (without the 25MB search index)**

```bash
mkdir -p public/data
cp ../zephyr-web-datahold/*.json public/data/
rm public/data/search_index.json
rm -rf ../zephyr-web-datahold
ls public/data | wc -l   # Expected: 67  (66 books + red_letter_verses.json)
```

- [ ] **Step 5: Replace `vite.config.ts` with base + vitest config**

```ts
/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/zephyr/' : '/',
  plugins: [react()],
  test: {
    environment: 'jsdom',
  },
}))
```

- [ ] **Step 6: Strip the scaffold to a blank shell**

Delete `src/App.css`, `src/assets/react.svg`, `public/vite.svg` (`git rm` after add). Create `src/styles/global.css`:

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #ffffff; --text: #1d1d1f; --text-secondary: #6e6e73;
  --accent: #0a84ff; --red-letter: #c0392b; --divider: rgba(0,0,0,0.12);
  --overlay-bg: rgba(255,255,255,0.92);
}
html, body, #root { height: 100%; }
body { background: var(--bg); color: var(--text); font-family: Georgia, serif; }
```

Replace `src/App.tsx`:

```tsx
export default function App() {
  return <div style={{ padding: 40 }}>Zephyr</div>
}
```

Replace `src/main.tsx`:

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/global.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode><App /></StrictMode>,
)
```

In `index.html` set `<title>Zephyr</title>` and `<html lang="en">`.

- [ ] **Step 7: Verify build and test runner**

```bash
npm run build            # Expected: builds with /zephyr/ base, no errors
npx vitest run --passWithNoTests   # Expected: "No test files found" exit 0
```

- [ ] **Step 8: Add scripts and commit**

In `package.json` scripts add `"test": "vitest run"` and `"generate-index": "node scripts/generate-bible-index.mjs"` (script created in Task 2).

```bash
git add -A
git commit -m "feat: scaffold Vite + React + TS with ESV data in public/data"
```

---

### Task 2: Bible index generation + navigation math (TDD)

**Files:**
- Create: `scripts/generate-bible-index.mjs`, `src/lib/types.ts`, `src/lib/bible-index.ts` (generated, committed), `src/lib/bible-nav.ts`
- Test: `src/lib/bible-nav.test.ts`

**Interfaces:**
- Produces:
  - `BOOKS: BookInfo[]` where `BookInfo = { name: string; slug: string; file: string; chapters: number; start: number }` (canonical order, `start` = cumulative global chapter offset), `TOTAL_CHAPTERS: number`
  - `bible-nav.ts`: `bookByName(name): BookInfo | undefined`, `bookBySlug(slug): BookInfo | undefined`, `globalIndex(pos: Position): number`, `positionForGlobalIndex(i: number): Position`, `chapterAfter(pos): Position | null`, `chapterBefore(pos): Position | null`, `slugForPosition(pos): string`
  - `src/lib/types.ts` with the shared interfaces from the header of this plan (copy them verbatim).

- [ ] **Step 1: Create `src/lib/types.ts`** with the interfaces block from "File Structure" above, verbatim.

- [ ] **Step 2: Write the generator `scripts/generate-bible-index.mjs`**

```js
import { readFileSync, writeFileSync } from 'node:fs'

// Canonical order, by file basename in public/data/
const ORDER = [
  'Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua','Judges','Ruth',
  '1Samuel','2Samuel','1Kings','2Kings','1Chronicles','2Chronicles','Ezra','Nehemiah',
  'Esther','Job','Psalm','Proverbs','Ecclesiastes','SongOfSolomon','Isaiah','Jeremiah',
  'Lamentations','Ezekiel','Daniel','Hosea','Joel','Amos','Obadiah','Jonah','Micah',
  'Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi',
  'Matthew','Mark','Luke','John','Acts','Romans','1Corinthians','2Corinthians',
  'Galatians','Ephesians','Philippians','Colossians','1Thessalonians','2Thessalonians',
  '1Timothy','2Timothy','Titus','Philemon','Hebrews','James','1Peter','2Peter',
  '1John','2John','3John','Jude','Revelation',
]

let start = 0
const entries = ORDER.map((base) => {
  const j = JSON.parse(readFileSync(`public/data/${base}.json`, 'utf8'))
  const slug = j.name.toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/ +/g, '-')
  const e = { name: j.name, slug, file: `${base}.json`, chapters: j.chapters.length, start }
  start += e.chapters
  return e
})

const out = `// GENERATED by scripts/generate-bible-index.mjs — do not edit by hand.
export interface BookInfo { name: string; slug: string; file: string; chapters: number; start: number }
export const BOOKS: BookInfo[] = ${JSON.stringify(entries, null, 2)}
export const TOTAL_CHAPTERS = ${start}
`
writeFileSync('src/lib/bible-index.ts', out)
console.log(`Wrote ${entries.length} books, ${start} chapters`)
```

- [ ] **Step 3: Run it**

```bash
npm run generate-index
```
Expected: `Wrote 66 books, 1189 chapters`. If the total is not 1189, STOP and investigate the data files before continuing.

- [ ] **Step 4: Write failing tests `src/lib/bible-nav.test.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { BOOKS, TOTAL_CHAPTERS } from './bible-index'
import { bookByName, bookBySlug, globalIndex, positionForGlobalIndex, chapterAfter, chapterBefore, slugForPosition } from './bible-nav'

describe('bible index', () => {
  it('has 66 books and 1189 chapters', () => {
    expect(BOOKS).toHaveLength(66)
    expect(TOTAL_CHAPTERS).toBe(1189)
  })
  it('knows chapter counts', () => {
    expect(bookByName('Genesis')!.chapters).toBe(50)
    expect(bookByName('Revelation')!.chapters).toBe(22)
  })
  it('looks up by slug', () => {
    expect(bookBySlug('1-corinthians')!.name).toBe('1 Corinthians')
    expect(bookBySlug('nope')).toBeUndefined()
  })
})

describe('global chapter math', () => {
  it('round-trips every chapter', () => {
    for (let i = 0; i < TOTAL_CHAPTERS; i++) {
      expect(globalIndex(positionForGlobalIndex(i))).toBe(i)
    }
  })
  it('Genesis 1 is index 0; Exodus 1 is index 50', () => {
    expect(globalIndex({ book: 'Genesis', chapter: 1 })).toBe(0)
    expect(globalIndex({ book: 'Exodus', chapter: 1 })).toBe(50)
  })
})

describe('chapter stepping', () => {
  it('steps within a book', () => {
    expect(chapterAfter({ book: 'Genesis', chapter: 1 })).toEqual({ book: 'Genesis', chapter: 2 })
    expect(chapterBefore({ book: 'Genesis', chapter: 2 })).toEqual({ book: 'Genesis', chapter: 1 })
  })
  it('crosses book boundaries', () => {
    expect(chapterAfter({ book: 'Genesis', chapter: 50 })).toEqual({ book: 'Exodus', chapter: 1 })
    expect(chapterBefore({ book: 'Exodus', chapter: 1 })).toEqual({ book: 'Genesis', chapter: 50 })
  })
  it('returns null at the ends', () => {
    expect(chapterBefore({ book: 'Genesis', chapter: 1 })).toBeNull()
    expect(chapterAfter({ book: 'Revelation', chapter: 22 })).toBeNull()
  })
  it('slugs positions', () => {
    expect(slugForPosition({ book: 'Song of Solomon', chapter: 3 })).toBe('song-of-solomon')
  })
})
```

- [ ] **Step 5: Run to verify failure**

```bash
npx vitest run src/lib/bible-nav.test.ts
```
Expected: FAIL — `bible-nav` module not found. (Note: if `bookByName('1 Corinthians')`-style names differ in the data — e.g. the Psalms book's `name` field — adjust the *tests'* expected display names to match `BOOKS` output, never the data.)

- [ ] **Step 6: Implement `src/lib/bible-nav.ts`**

```ts
import { BOOKS, TOTAL_CHAPTERS, type BookInfo } from './bible-index'
import type { Position } from './types'

const byName = new Map(BOOKS.map((b) => [b.name, b]))
const bySlug = new Map(BOOKS.map((b) => [b.slug, b]))

export function bookByName(name: string): BookInfo | undefined { return byName.get(name) }
export function bookBySlug(slug: string): BookInfo | undefined { return bySlug.get(slug) }

export function globalIndex(pos: Position): number {
  const b = byName.get(pos.book)
  if (!b) throw new Error(`Unknown book: ${pos.book}`)
  return b.start + pos.chapter - 1
}

export function positionForGlobalIndex(i: number): Position {
  const clamped = Math.max(0, Math.min(TOTAL_CHAPTERS - 1, i))
  for (let k = BOOKS.length - 1; k >= 0; k--) {
    if (BOOKS[k].start <= clamped) return { book: BOOKS[k].name, chapter: clamped - BOOKS[k].start + 1 }
  }
  return { book: BOOKS[0].name, chapter: 1 }
}

export function chapterAfter(pos: Position): Position | null {
  const i = globalIndex(pos)
  return i >= TOTAL_CHAPTERS - 1 ? null : positionForGlobalIndex(i + 1)
}

export function chapterBefore(pos: Position): Position | null {
  const i = globalIndex(pos)
  return i <= 0 ? null : positionForGlobalIndex(i - 1)
}

export function slugForPosition(pos: Position): string {
  const b = byName.get(pos.book)
  if (!b) throw new Error(`Unknown book: ${pos.book}`)
  return b.slug
}
```

- [ ] **Step 7: Run tests to verify pass**

```bash
npx vitest run src/lib/bible-nav.test.ts
```
Expected: PASS (all).

- [ ] **Step 8: Commit**

```bash
git add scripts/generate-bible-index.mjs src/lib
git commit -m "feat: bible index generation and chapter navigation math"
```

---

### Task 3: Storage module (TDD)

**Files:**
- Create: `src/lib/storage.ts`
- Test: `src/lib/storage.test.ts`

**Interfaces:**
- Produces: `KEYS = { highlights: 'zephyr.v1.highlights', bookmarks: 'zephyr.v1.bookmarks', history: 'zephyr.v1.history', prefs: 'zephyr.v1.prefs' }`, `loadJSON<T>(key: string, fallback: T): T`, `saveJSON(key: string, value: unknown): void`

- [ ] **Step 1: Write failing test `src/lib/storage.test.ts`**

```ts
import { describe, it, expect, beforeEach } from 'vitest'
import { KEYS, loadJSON, saveJSON } from './storage'

beforeEach(() => localStorage.clear())

describe('storage', () => {
  it('round-trips values', () => {
    saveJSON(KEYS.bookmarks, [{ book: 'John', chapter: 3 }])
    expect(loadJSON(KEYS.bookmarks, [])).toEqual([{ book: 'John', chapter: 3 }])
  })
  it('returns fallback when missing', () => {
    expect(loadJSON(KEYS.history, [])).toEqual([])
  })
  it('returns fallback on corrupted JSON', () => {
    localStorage.setItem(KEYS.prefs, '{not json')
    expect(loadJSON(KEYS.prefs, { theme: 'system' })).toEqual({ theme: 'system' })
  })
  it('uses zephyr.v1 prefix', () => {
    expect(Object.values(KEYS).every((k) => k.startsWith('zephyr.v1.'))).toBe(true)
  })
})
```

- [ ] **Step 2: Run to verify failure** — `npx vitest run src/lib/storage.test.ts` → FAIL (module not found).

- [ ] **Step 3: Implement `src/lib/storage.ts`**

```ts
export const KEYS = {
  highlights: 'zephyr.v1.highlights',
  bookmarks: 'zephyr.v1.bookmarks',
  history: 'zephyr.v1.history',
  prefs: 'zephyr.v1.prefs',
} as const

export function loadJSON<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    if (raw == null) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function saveJSON(key: string, value: unknown): void {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Quota exceeded or unavailable — reading must never break.
  }
}
```

- [ ] **Step 4: Run tests** → PASS. **Step 5: Commit** — `git add src/lib/storage*; git commit -m "feat: versioned localStorage wrapper"`

---

### Task 4: Bible data loader (TDD)

**Files:**
- Create: `src/lib/bible-data.ts`
- Test: `src/lib/bible-data.test.ts`

**Interfaces:**
- Consumes: `BOOKS` (Task 2), `Book` type.
- Produces: `loadBook(name: string): Promise<Book>` (memoized, keyed by display name), `loadAllBooks(onProgress?: (loaded: number, total: number) => void): Promise<Book[]>`, `loadRedLetter(): Promise<RedLetterMap>` where `RedLetterMap = Record<string, Record<string, number[]>>` (book → chapter → red verse numbers), `_resetCacheForTests(): void`

- [ ] **Step 1: Write failing test `src/lib/bible-data.test.ts`**

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { loadBook, loadAllBooks, loadRedLetter, _resetCacheForTests } from './bible-data'

const fakeBook = { name: 'Genesis', chapters: [{ number: 1, verses: [{ number: 1, text: 'In the beginning' }] }] }

beforeEach(() => {
  _resetCacheForTests()
  vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
    ok: true,
    json: async () => (String(url).includes('red_letter') ? { Matthew: { '3': [15] } } : fakeBook),
  })))
})

describe('bible-data', () => {
  it('fetches a book by display name from BASE_URL/data', async () => {
    const b = await loadBook('Genesis')
    expect(b.name).toBe('Genesis')
    expect(fetch).toHaveBeenCalledWith(expect.stringContaining('data/Genesis.json'))
  })
  it('memoizes: second load does not refetch', async () => {
    await loadBook('Genesis')
    await loadBook('Genesis')
    expect(fetch).toHaveBeenCalledTimes(1)
  })
  it('rejects on unknown book', async () => {
    await expect(loadBook('Atlantis')).rejects.toThrow()
  })
  it('rejects on HTTP failure', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 404 })))
    await expect(loadBook('Genesis')).rejects.toThrow('404')
  })
  it('loads all books with progress', async () => {
    const ticks: number[] = []
    const all = await loadAllBooks((n) => ticks.push(n))
    expect(all).toHaveLength(66)
    expect(ticks.at(-1)).toBe(66)
  })
  it('loads red letter map', async () => {
    const rl = await loadRedLetter()
    expect(rl.Matthew['3']).toEqual([15])
  })
})
```

- [ ] **Step 2: Run to verify failure** → FAIL (module not found).

- [ ] **Step 3: Implement `src/lib/bible-data.ts`**

```ts
import { BOOKS } from './bible-index'
import { bookByName } from './bible-nav'
import type { Book } from './types'

export type RedLetterMap = Record<string, Record<string, number[]>>

const dataUrl = (file: string) => `${import.meta.env.BASE_URL}data/${file}`

let bookCache = new Map<string, Promise<Book>>()
let redLetterCache: Promise<RedLetterMap> | null = null

async function fetchJSON<T>(url: string): Promise<T> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`)
  return res.json() as Promise<T>
}

export function loadBook(name: string): Promise<Book> {
  const info = bookByName(name)
  if (!info) return Promise.reject(new Error(`Unknown book: ${name}`))
  let p = bookCache.get(name)
  if (!p) {
    p = fetchJSON<Book>(dataUrl(info.file))
    p.catch(() => bookCache.delete(name)) // allow retry after failure
    bookCache.set(name, p)
  }
  return p
}

export async function loadAllBooks(onProgress?: (loaded: number, total: number) => void): Promise<Book[]> {
  let done = 0
  return Promise.all(
    BOOKS.map(async (b) => {
      const book = await loadBook(b.name)
      onProgress?.(++done, BOOKS.length)
      return book
    }),
  )
}

export function loadRedLetter(): Promise<RedLetterMap> {
  redLetterCache ??= fetchJSON<RedLetterMap>(dataUrl('red_letter_verses.json'))
  return redLetterCache
}

export function _resetCacheForTests(): void {
  bookCache = new Map()
  redLetterCache = null
}
```

- [ ] **Step 4: Run tests** → PASS. **Step 5: Commit** — `git add src/lib/bible-data*; git commit -m "feat: lazy book loader with memoized fetch and red letter map"`

---

### Task 5: Reference parser (TDD)

**Files:**
- Create: `src/lib/reference-parser.ts`
- Test: `src/lib/reference-parser.test.ts`

**Interfaces:**
- Consumes: `BOOKS`, `bookByName`.
- Produces: `parseReference(input: string): ParsedReference | null` where `ParsedReference = { book: string; chapter: number; verse?: number; verseEnd?: number }`. Returns `null` when the input is not a recognizable reference (caller falls through to keyword search). Chapter is clamped to the book's chapter count.

- [ ] **Step 1: Write failing test `src/lib/reference-parser.test.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { parseReference } from './reference-parser'

describe('parseReference', () => {
  it('parses book chapter:verse', () => {
    expect(parseReference('John 3:16')).toEqual({ book: 'John', chapter: 3, verse: 16 })
  })
  it('parses verse ranges', () => {
    expect(parseReference('1 cor 13:4-7')).toEqual({ book: '1 Corinthians', chapter: 13, verse: 4, verseEnd: 7 })
  })
  it('parses common abbreviations', () => {
    expect(parseReference('gen 1')).toEqual({ book: 'Genesis', chapter: 1 })
    expect(parseReference('ps 23')).toEqual({ book: expect.stringMatching(/^Psalm/), chapter: 23 })
    expect(parseReference('sos 2')).toEqual({ book: 'Song of Solomon', chapter: 2 })
  })
  it('parses roman-numeral ordinals and periods', () => {
    expect(parseReference('II Tim. 2:15')).toEqual({ book: '2 Timothy', chapter: 2, verse: 15 })
  })
  it('book-only goes to chapter 1', () => {
    expect(parseReference('jude')).toEqual({ book: 'Jude', chapter: 1 })
  })
  it('clamps out-of-range chapters', () => {
    expect(parseReference('john 99')).toEqual({ book: 'John', chapter: 21 })
  })
  it('rejects non-references', () => {
    expect(parseReference('love is patient')).toBeNull()
    expect(parseReference('')).toBeNull()
  })
})
```

- [ ] **Step 2: Run to verify failure** → FAIL (module not found).

- [ ] **Step 3: Implement `src/lib/reference-parser.ts`**

```ts
import { BOOKS } from './bible-index'
import { bookByName } from './bible-nav'

export interface ParsedReference { book: string; chapter: number; verse?: number; verseEnd?: number }

// Normalized alias → canonical display name. Full names and slugs are added automatically below.
const ALIASES: Record<string, string> = {
  gen: 'Genesis', ex: 'Exodus', exod: 'Exodus', lev: 'Leviticus', num: 'Numbers',
  deut: 'Deuteronomy', dt: 'Deuteronomy', josh: 'Joshua', judg: 'Judges', jdg: 'Judges',
  ru: 'Ruth', '1 sam': '1 Samuel', '2 sam': '2 Samuel', '1 kgs': '1 Kings', '2 kgs': '2 Kings',
  '1 chr': '1 Chronicles', '2 chr': '2 Chronicles', neh: 'Nehemiah', est: 'Esther',
  ps: 'Psalms', psa: 'Psalms', psalm: 'Psalms', prov: 'Proverbs', pr: 'Proverbs',
  eccl: 'Ecclesiastes', ecc: 'Ecclesiastes', song: 'Song of Solomon', sos: 'Song of Solomon',
  isa: 'Isaiah', jer: 'Jeremiah', lam: 'Lamentations', ezek: 'Ezekiel', dan: 'Daniel',
  hos: 'Hosea', ob: 'Obadiah', obad: 'Obadiah', jon: 'Jonah', mic: 'Micah', nah: 'Nahum',
  hab: 'Habakkuk', zeph: 'Zephaniah', hag: 'Haggai', zech: 'Zechariah', mal: 'Malachi',
  mt: 'Matthew', matt: 'Matthew', mk: 'Mark', lk: 'Luke', jn: 'John', rom: 'Romans',
  '1 cor': '1 Corinthians', '2 cor': '2 Corinthians', gal: 'Galatians', eph: 'Ephesians',
  phil: 'Philippians', col: 'Colossians', '1 thess': '1 Thessalonians', '2 thess': '2 Thessalonians',
  '1 tim': '1 Timothy', '2 tim': '2 Timothy', tit: 'Titus', phlm: 'Philemon', heb: 'Hebrews',
  jas: 'James', '1 pet': '1 Peter', '2 pet': '2 Peter', '1 jn': '1 John', '2 jn': '2 John',
  '3 jn': '3 John', rev: 'Revelation',
}

const lookup = new Map<string, string>()
for (const b of BOOKS) {
  lookup.set(b.name.toLowerCase(), b.name)
  lookup.set(b.slug.replace(/-/g, ' '), b.name)
}
for (const [alias, name] of Object.entries(ALIASES)) {
  // Alias targets use common names; map "Psalms" → whatever the data calls it.
  const resolved = bookByName(name) ?? BOOKS.find((b) => name.toLowerCase().startsWith(b.name.toLowerCase()))
  if (resolved) lookup.set(alias, resolved.name)
}

function normalize(input: string): string {
  return input
    .toLowerCase()
    .replace(/\./g, '')
    .replace(/^iii\s+/, '3 ').replace(/^ii\s+/, '2 ').replace(/^i\s+/, '1 ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function parseReference(input: string): ParsedReference | null {
  const norm = normalize(input)
  if (!norm) return null
  const m = norm.match(/^(\d?\s?[a-z ]+?)(?:\s+(\d+)(?::(\d+)(?:\s*[-–]\s*(\d+))?)?)?$/)
  if (!m) return null
  const bookName = lookup.get(m[1].trim())
  if (!bookName) return null
  const info = bookByName(bookName)!
  const chapter = m[2] ? Math.max(1, Math.min(info.chapters, parseInt(m[2], 10))) : 1
  const ref: ParsedReference = { book: bookName, chapter }
  if (m[3]) ref.verse = parseInt(m[3], 10)
  if (m[4]) ref.verseEnd = parseInt(m[4], 10)
  return ref
}
```

- [ ] **Step 4: Run tests** → PASS. (If the Psalms display name in `bible-index.ts` is `"Psalm"`, the regex matcher in the test already tolerates it; ensure the `ps` alias resolves via the fallback `startsWith` logic.)

- [ ] **Step 5: Commit** — `git add src/lib/reference-parser*; git commit -m "feat: bible reference parser with abbreviations"`

---

### Task 6: Keyword search (TDD)

**Files:**
- Create: `src/lib/search.ts`
- Test: `src/lib/search.test.ts`

**Interfaces:**
- Consumes: `Book` type.
- Produces: `searchVerses(query: string, books: Book[], limit?: number): SearchResult[]` where `SearchResult = { book: string; chapter: number; verse: number; text: string; matchStart: number; matchEnd: number }`. Case-insensitive substring match; default limit 200.

- [ ] **Step 1: Write failing test `src/lib/search.test.ts`**

```ts
import { describe, it, expect } from 'vitest'
import { searchVerses } from './search'
import type { Book } from './types'

const books: Book[] = [{
  name: 'TestBook',
  chapters: [{ number: 1, verses: [
    { number: 1, text: 'For God so loved the world' },
    { number: 2, text: 'Love is patient, love is kind' },
    { number: 3, text: 'Nothing here' },
  ]}],
}]

describe('searchVerses', () => {
  it('finds case-insensitive matches with offsets', () => {
    const r = searchVerses('loved', books)
    expect(r).toHaveLength(1)
    expect(r[0]).toMatchObject({ book: 'TestBook', chapter: 1, verse: 1, matchStart: 11, matchEnd: 16 })
  })
  it('matches once per verse', () => {
    expect(searchVerses('love', books)).toHaveLength(2)
  })
  it('respects the limit', () => {
    expect(searchVerses('o', books, 1)).toHaveLength(1)
  })
  it('empty/whitespace query returns nothing', () => {
    expect(searchVerses('  ', books)).toEqual([])
  })
})
```

- [ ] **Step 2: Run to verify failure** → FAIL. **Step 3: Implement `src/lib/search.ts`**

```ts
import type { Book } from './types'

export interface SearchResult { book: string; chapter: number; verse: number; text: string; matchStart: number; matchEnd: number }

export function searchVerses(query: string, books: Book[], limit = 200): SearchResult[] {
  const q = query.trim().toLowerCase()
  if (!q) return []
  const results: SearchResult[] = []
  for (const book of books) {
    for (const ch of book.chapters) {
      for (const v of ch.verses) {
        const idx = v.text.toLowerCase().indexOf(q)
        if (idx >= 0) {
          results.push({ book: book.name, chapter: ch.number, verse: v.number, text: v.text, matchStart: idx, matchEnd: idx + q.length })
          if (results.length >= limit) return results
        }
      }
    }
  }
  return results
}
```

- [ ] **Step 4: Run tests** → PASS. **Step 5: Commit** — `git commit -am "feat: keyword search over loaded books"` (after `git add src/lib/search*`).

---

### Task 7: Label spacing + bionic transform (TDD)

**Files:**
- Create: `src/lib/label-spacing.ts`, `src/lib/bionic.ts`
- Test: `src/lib/label-spacing.test.ts`, `src/lib/bionic.test.ts`

**Interfaces:**
- Produces:
  - `spaceLabels(midFractions: number[], trackHeightPx: number, minGapPx?: number): number[]` — port of native `spacedLabelFractions` (forward pass pushes overlaps down, backward pass pushes back up; last label clamped to 1 before the backward pass; default gap 20px). Output fractions MAY be <0 or >1 when the track is short — callers clip.
  - `bionicWords(text: string): Array<{ bold: string; rest: string }>` — splits on whitespace runs (kept in `rest` of the preceding token); bold prefix = `ceil(0.4 × word length)` letters.

- [ ] **Step 1: Write failing tests**

`src/lib/label-spacing.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { spaceLabels } from './label-spacing'

describe('spaceLabels', () => {
  it('leaves well-spaced labels alone', () => {
    expect(spaceLabels([0.1, 0.5, 0.9], 1000)).toEqual([0.1, 0.5, 0.9])
  })
  it('enforces min gap on crowded labels', () => {
    const out = spaceLabels([0.5, 0.5, 0.5], 1000, 20) // gap fraction 0.02
    expect(out[1] - out[0]).toBeCloseTo(0.02, 5)
    expect(out[2] - out[1]).toBeCloseTo(0.02, 5)
  })
  it('clamps the last label to 1 and pushes predecessors up', () => {
    const out = spaceLabels([0.99, 0.995, 1.0], 1000, 20)
    expect(out[2]).toBe(1)
    expect(out[2] - out[1]).toBeCloseTo(0.02, 5)
    expect(out[1] - out[0]).toBeCloseTo(0.02, 5)
  })
  it('preserves order for 66 crowded labels', () => {
    const mids = Array.from({ length: 66 }, (_, i) => i / 65)
    const out = spaceLabels(mids, 600, 20) // 66*20 > 600 → overflow expected
    for (let i = 1; i < out.length; i++) expect(out[i] - out[i - 1]).toBeGreaterThanOrEqual(0.0333 - 1e-9)
  })
})
```

`src/lib/bionic.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { bionicWords } from './bionic'

describe('bionicWords', () => {
  it('bolds ~40% of each word', () => {
    expect(bionicWords('beginning')).toEqual([{ bold: 'begi', rest: 'nning' }])
  })
  it('keeps whitespace attached', () => {
    expect(bionicWords('in the')).toEqual([{ bold: 'i', rest: 'n ' }, { bold: 't', rest: 'he' }])
  })
  it('handles empty text', () => {
    expect(bionicWords('')).toEqual([])
  })
})
```

- [ ] **Step 2: Run to verify failure** → FAIL (modules not found).

- [ ] **Step 3: Implement**

`src/lib/label-spacing.ts`:

```ts
/** Port of the native BibleScrubber.spacedLabelFractions (forward+backward min-gap pass). */
export function spaceLabels(midFractions: number[], trackHeightPx: number, minGapPx = 20): number[] {
  const gap = trackHeightPx > 0 ? minGapPx / trackHeightPx : 0
  const out = [...midFractions]
  for (let i = 1; i < out.length; i++) {
    if (out[i] < out[i - 1] + gap) out[i] = out[i - 1] + gap
  }
  if (out.length && out[out.length - 1] > 1) out[out.length - 1] = 1
  for (let i = out.length - 2; i >= 0; i--) {
    if (out[i] > out[i + 1] - gap) out[i] = out[i + 1] - gap
  }
  return out
}
```

`src/lib/bionic.ts`:

```ts
export function bionicWords(text: string): Array<{ bold: string; rest: string }> {
  if (!text) return []
  const tokens = text.split(/(\s+)/)
  const out: Array<{ bold: string; rest: string }> = []
  for (const tok of tokens) {
    if (!tok) continue
    if (/^\s+$/.test(tok)) {
      if (out.length) out[out.length - 1].rest += tok
      else out.push({ bold: '', rest: tok })
    } else {
      const n = Math.ceil(tok.length * 0.4)
      out.push({ bold: tok.slice(0, n), rest: tok.slice(n) })
    }
  }
  return out
}
```

- [ ] **Step 4: Run all tests** — `npx vitest run` → PASS. **Step 5: Commit** — `git add src/lib/label-spacing* src/lib/bionic*; git commit -m "feat: scrubber label spacing and bionic reading transforms"`

---

### Task 8: Prefs context, themes, settings popover

**Files:**
- Create: `src/state/prefs.tsx`, `src/components/SettingsPopover.tsx`
- Modify: `src/styles/global.css`, `src/App.tsx` (wrap provider)
- Test: `src/state/prefs.test.tsx`

**Interfaces:**
- Consumes: `storage.ts`, `Prefs` type.
- Produces: `PrefsProvider`, `usePrefs(): { prefs: Prefs; setPref<K extends keyof Prefs>(k: K, v: Prefs[K]): void }`. Applying `prefs.theme` sets `data-theme` on `document.documentElement` (`system` resolves via `matchMedia('(prefers-color-scheme: dark)')` to `light`/`dark`). `prefs.font` sets `data-font`.

- [ ] **Step 1: Write failing test `src/state/prefs.test.tsx`**

```tsx
import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { PrefsProvider, usePrefs } from './prefs'

beforeEach(() => localStorage.clear())
const wrapper = ({ children }: { children: React.ReactNode }) => <PrefsProvider>{children}</PrefsProvider>

describe('prefs', () => {
  it('defaults and persists', () => {
    const { result } = renderHook(() => usePrefs(), { wrapper })
    expect(result.current.prefs.font).toBe('georgia')
    act(() => result.current.setPref('theme', 'sepia'))
    expect(document.documentElement.dataset.theme).toBe('sepia')
    expect(JSON.parse(localStorage.getItem('zephyr.v1.prefs')!)).toMatchObject({ theme: 'sepia' })
  })
})
```

Install the test util first: `npm install -D @testing-library/react`.

- [ ] **Step 2: Run to verify failure** → FAIL. **Step 3: Implement `src/state/prefs.tsx`**

```tsx
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { KEYS, loadJSON, saveJSON } from '../lib/storage'
import type { Prefs } from '../lib/types'

const DEFAULTS: Prefs = { theme: 'system', font: 'georgia', redLetter: true, bionic: false }

interface PrefsCtx { prefs: Prefs; setPref: <K extends keyof Prefs>(k: K, v: Prefs[K]) => void }
const Ctx = createContext<PrefsCtx | null>(null)

function resolveTheme(theme: Prefs['theme']): string {
  if (theme !== 'system') return theme
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [prefs, setPrefs] = useState<Prefs>(() => ({ ...DEFAULTS, ...loadJSON(KEYS.prefs, DEFAULTS) }))

  useEffect(() => {
    document.documentElement.dataset.theme = resolveTheme(prefs.theme)
    document.documentElement.dataset.font = prefs.font
    saveJSON(KEYS.prefs, prefs)
    if (prefs.theme !== 'system') return
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => { document.documentElement.dataset.theme = resolveTheme('system') }
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [prefs])

  const setPref: PrefsCtx['setPref'] = (k, v) => setPrefs((p) => ({ ...p, [k]: v }))
  return <Ctx.Provider value={{ prefs, setPref }}>{children}</Ctx.Provider>
}

export function usePrefs(): PrefsCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('usePrefs outside PrefsProvider')
  return ctx
}
```

- [ ] **Step 4: Add theme variables to `src/styles/global.css`** (replace the `:root` block):

```css
:root, :root[data-theme='light'] {
  --bg: #ffffff; --text: #1d1d1f; --text-secondary: #6e6e73;
  --accent: #0a84ff; --red-letter: #c0392b; --divider: rgba(0,0,0,0.12);
  --overlay-bg: rgba(255,255,255,0.92); --hover: rgba(0,0,0,0.06);
}
:root[data-theme='dark'] {
  --bg: #1e1e1e; --text: #e8e8ed; --text-secondary: #98989d;
  --accent: #0a84ff; --red-letter: #e06055; --divider: rgba(255,255,255,0.14);
  --overlay-bg: rgba(30,30,30,0.92); --hover: rgba(255,255,255,0.08);
}
:root[data-theme='sepia'] {
  --bg: #f4ecd8; --text: #3d3428; --text-secondary: #7a6f5d;
  --accent: #8a6d3b; --red-letter: #a53f2b; --divider: rgba(61,52,40,0.18);
  --overlay-bg: rgba(244,236,216,0.94); --hover: rgba(61,52,40,0.08);
}
:root[data-theme='black'] {
  --bg: #000000; --text: #d8d8dc; --text-secondary: #808085;
  --accent: #0a84ff; --red-letter: #e06055; --divider: rgba(255,255,255,0.12);
  --overlay-bg: rgba(0,0,0,0.92); --hover: rgba(255,255,255,0.1);
}
:root[data-font='georgia'] { --reading-font: Georgia, 'Times New Roman', serif; }
:root[data-font='palatino'] { --reading-font: 'Palatino', 'Palatino Linotype', 'Book Antiqua', serif; }
:root[data-font='helvetica'] { --reading-font: 'Helvetica Neue', Helvetica, Arial, sans-serif; }
body { background: var(--bg); color: var(--text); font-family: var(--reading-font, Georgia, serif); transition: background 0.2s, color 0.2s; }
```

- [ ] **Step 5: Create `src/components/SettingsPopover.tsx`**

```tsx
import { usePrefs } from '../state/prefs'
import type { Prefs } from '../lib/types'

const THEMES: Prefs['theme'][] = ['system', 'light', 'dark', 'sepia', 'black']
const FONTS: Array<{ id: Prefs['font']; label: string }> = [
  { id: 'georgia', label: 'Georgia' }, { id: 'palatino', label: 'Palatino' }, { id: 'helvetica', label: 'Helvetica Neue' },
]

export default function SettingsPopover({ onClose }: { onClose: () => void }) {
  const { prefs, setPref } = usePrefs()
  return (
    <div className="popover-backdrop" onClick={onClose}>
      <div className="settings-popover" onClick={(e) => e.stopPropagation()}>
        <div className="settings-group">
          <span className="settings-label">Theme</span>
          <div className="settings-row">
            {THEMES.map((t) => (
              <button key={t} className={prefs.theme === t ? 'chip active' : 'chip'} onClick={() => setPref('theme', t)}>{t}</button>
            ))}
          </div>
        </div>
        <div className="settings-group">
          <span className="settings-label">Font</span>
          <div className="settings-row">
            {FONTS.map((f) => (
              <button key={f.id} className={prefs.font === f.id ? 'chip active' : 'chip'} onClick={() => setPref('font', f.id)}>{f.label}</button>
            ))}
          </div>
        </div>
        <div className="settings-group">
          <label className="settings-toggle"><input type="checkbox" checked={prefs.redLetter} onChange={(e) => setPref('redLetter', e.target.checked)} /> Red letter</label>
          <label className="settings-toggle"><input type="checkbox" checked={prefs.bionic} onChange={(e) => setPref('bionic', e.target.checked)} /> Bionic reading</label>
        </div>
      </div>
    </div>
  )
}
```

Add to `global.css`:

```css
.popover-backdrop { position: fixed; inset: 0; z-index: 40; }
.settings-popover { position: absolute; top: 44px; right: 12px; width: 280px; background: var(--overlay-bg); backdrop-filter: blur(12px); border: 1px solid var(--divider); border-radius: 10px; padding: 14px; box-shadow: 0 8px 30px rgba(0,0,0,0.2); font-family: -apple-system, system-ui, sans-serif; font-size: 13px; }
.settings-group { margin-bottom: 12px; }
.settings-label { color: var(--text-secondary); font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
.settings-row { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 6px; }
.chip { border: 1px solid var(--divider); background: transparent; color: var(--text); border-radius: 999px; padding: 3px 10px; cursor: pointer; font-size: 12px; text-transform: capitalize; }
.chip.active { background: var(--accent); border-color: var(--accent); color: #fff; }
.settings-toggle { display: block; margin-top: 6px; cursor: pointer; }
```

- [ ] **Step 6: Run tests** — `npx vitest run` → PASS. **Step 7: Commit** — `git add -A; git commit -m "feat: prefs context with themes, fonts, and settings popover"`

---

### Task 9: Chapter rendering (ChapterView + VerseText)

**Files:**
- Create: `src/components/ChapterView.tsx`, `src/components/VerseText.tsx`
- Modify: `src/styles/global.css`, `src/App.tsx` (temporary harness)

**Interfaces:**
- Consumes: `Chapter`/`Verse` types, `bionicWords`, `usePrefs`, `RedLetterMap`, `Highlight`.
- Produces:
  - `ChapterView({ book, chapter, showBookTitle, redLetter, highlights, bookmarked, targetVerseRange })` — renders one chapter; root element carries `data-book` and `data-chapter` attributes (ReadingPane relies on them).
  - `VerseText({ verse, isRed, highlights, bionic })` — one verse `<span class="verse" data-verse={n}>`; char offsets in highlight records index into `verse.text` exactly.

- [ ] **Step 1: Create `src/components/VerseText.tsx`**

```tsx
import { Fragment } from 'react'
import type { Verse, Highlight } from '../lib/types'
import { bionicWords } from '../lib/bionic'

interface Props { verse: Verse; isRed: boolean; highlights: Highlight[]; bionic: boolean }

/** Split verse text into segments at highlight boundaries. */
function segments(text: string, hls: Highlight[]): Array<{ text: string; color?: string }> {
  if (!hls.length) return [{ text }]
  const bounds = new Set([0, text.length])
  for (const h of hls) { bounds.add(Math.max(0, h.startChar)); bounds.add(Math.min(text.length, h.endChar)) }
  const cuts = [...bounds].sort((a, b) => a - b)
  const out: Array<{ text: string; color?: string }> = []
  for (let i = 0; i < cuts.length - 1; i++) {
    const [s, e] = [cuts[i], cuts[i + 1]]
    const hl = hls.find((h) => h.startChar <= s && h.endChar >= e)
    out.push({ text: text.slice(s, e), color: hl?.color })
  }
  return out
}

function renderText(text: string, bionic: boolean) {
  if (!bionic) return text
  return bionicWords(text).map((w, i) => (
    <Fragment key={i}><b>{w.bold}</b>{w.rest}</Fragment>
  ))
}

export default function VerseText({ verse, isRed, highlights, bionic }: Props) {
  return (
    <span className={isRed ? 'verse red-letter' : 'verse'} data-verse={verse.number}>
      <sup className="verse-num">{verse.number}</sup>
      {segments(verse.text, highlights).map((seg, i) =>
        seg.color
          ? <mark key={i} className={`hl hl-${seg.color}`}>{renderText(seg.text, bionic)}</mark>
          : <Fragment key={i}>{renderText(seg.text, bionic)}</Fragment>,
      )}
    </span>
  )
}
```

- [ ] **Step 2: Create `src/components/ChapterView.tsx`**

```tsx
import { useMemo } from 'react'
import type { Chapter, Highlight } from '../lib/types'
import { usePrefs } from '../state/prefs'
import VerseText from './VerseText'

interface Props {
  bookName: string
  chapter: Chapter
  showBookTitle: boolean
  redVerses: number[]           // verse numbers in this chapter that are red-letter
  highlights: Highlight[]       // highlights for this chapter only
  bookmarked: boolean
  targetVerseRange?: { start: number; end: number } | null  // flash highlight from search nav
}

export default function ChapterView({ bookName, chapter, showBookTitle, redVerses, highlights, bookmarked, targetVerseRange }: Props) {
  const { prefs } = usePrefs()
  const redSet = useMemo(() => new Set(prefs.redLetter ? redVerses : []), [prefs.redLetter, redVerses])
  const oneVersePerLine = bookName === 'Proverbs'
  const inTarget = (n: number) => !!targetVerseRange && n >= targetVerseRange.start && n <= targetVerseRange.end

  return (
    <section className="chapter" data-book={bookName} data-chapter={chapter.number}>
      {showBookTitle && <h1 className="book-title">{bookName}</h1>}
      <div className="chapter-body">
        <span className="drop-cap">
          {chapter.number}
          {bookmarked && <span className="bookmark-flag" title="Bookmarked">&#9873;</span>}
        </span>
        <p className={oneVersePerLine ? 'verses verses-lines' : 'verses'}>
          {chapter.verses.map((v) => (
            <span key={v.number} className={inTarget(v.number) ? 'verse-target' : undefined}>
              <VerseText verse={v} isRed={redSet.has(v.number)} highlights={highlights.filter((h) => h.verse === v.number)} bionic={prefs.bionic} />
              {oneVersePerLine ? '\n' : ' '}
            </span>
          ))}
        </p>
      </div>
      <hr className="chapter-divider" />
    </section>
  )
}
```

- [ ] **Step 3: Add reading styles to `global.css`**

```css
.chapter { max-width: 700px; margin: 0 auto; padding: 24px 32px 0; }
.book-title { font-family: -apple-system, system-ui, sans-serif; font-size: 28px; font-weight: 700; padding: 16px 0 12px; }
.chapter-body { position: relative; }
.drop-cap { float: left; font-size: 42px; line-height: 1; font-weight: 500; padding: 4px 10px 0 0; font-family: var(--reading-font); }
.bookmark-flag { color: var(--accent); font-size: 14px; vertical-align: top; margin-left: 2px; }
.verses { font-size: 17px; line-height: 1.65; white-space: pre-wrap; text-align: left; }
.verses-lines .verse { display: block; }
.verse-num { color: var(--text-secondary); font-size: 11px; margin-right: 3px; font-family: -apple-system, system-ui, sans-serif; }
.red-letter { color: var(--red-letter); }
.red-letter .verse-num { color: var(--text-secondary); }
.hl-yellow { background: rgba(255, 214, 10, 0.35); } .hl-green { background: rgba(48, 209, 88, 0.3); }
.hl-blue { background: rgba(10, 132, 255, 0.25); } .hl-pink { background: rgba(255, 55, 95, 0.25); }
.hl-purple { background: rgba(191, 90, 242, 0.3); }
.hl { color: inherit; }
.verse-target { background: rgba(10, 132, 255, 0.15); transition: background 1.2s ease 1.5s; border-radius: 3px; }
.chapter-divider { border: none; border-top: 1px solid var(--divider); margin: 24px 0; max-width: 700px; }
```

- [ ] **Step 4: Temporary visual harness** — replace `src/App.tsx` body with:

```tsx
import { useEffect, useState } from 'react'
import { PrefsProvider } from './state/prefs'
import ChapterView from './components/ChapterView'
import { loadBook, loadRedLetter } from './lib/bible-data'
import type { Book } from './lib/types'

export default function App() {
  const [book, setBook] = useState<Book | null>(null)
  const [red, setRed] = useState<number[]>([])
  useEffect(() => {
    loadBook('Isaiah').then(setBook)
    loadRedLetter().then((m) => setRed(m['Isaiah']?.['40'] ?? []))
  }, [])
  if (!book) return null
  const ch = book.chapters.find((c) => c.number === 40)!
  return (
    <PrefsProvider>
      <ChapterView bookName="Isaiah" chapter={ch} showBookTitle={false} redVerses={red} highlights={[]} bookmarked={false} />
    </PrefsProvider>
  )
}
```

- [ ] **Step 5: Manual verification** — `npm run dev`, open http://localhost:5173. Compare against `~/Projects/Zephyr/docs/bible_scrubber.png` (Isaiah 40): poetry lines indent identically (embedded newlines + 4-space indents render via `pre-wrap`), superscript verse numbers, 42px drop-cap "40". Also check Matthew 5 shows red letter by editing the harness book/chapter temporarily.

- [ ] **Step 6: Run tests + commit**

```bash
npx vitest run   # Expected: all previous suites still PASS
git add -A && git commit -m "feat: chapter and verse rendering with poetry, red letter, highlights, bionic"
```

---

### Task 10: ReadingPane infinite scroll + Reader route

**Files:**
- Create: `src/components/ReadingPane.tsx`, `src/components/Reader.tsx`
- Modify: `src/App.tsx`, `src/main.tsx`, `src/styles/global.css`

**Interfaces:**
- Consumes: `chapterAfter/chapterBefore/globalIndex/positionForGlobalIndex/bookBySlug/slugForPosition`, `loadBook`, `loadRedLetter`, `ChapterView`.
- Produces:
  - `ReadingPane({ target, navId, targetVerseRange, onPositionChange })` — `navId` change resets the list to `[target]`; `onPositionChange(pos: Position)` fires when the topmost visible chapter changes.
  - `Reader` — route component for `/:slug?/:chapter?`; owns navigation: `jump(pos, verseRange?)` navigates the router (pushes history); scroll-driven position updates use `window.history.replaceState`.
  - App context `NavContext` with `{ position: Position; jump(pos: Position, verseRange?: {start:number; end:number}): void }` exported from `Reader.tsx` via `useNav()` — overlays and the scrubber consume this.

- [ ] **Step 1: Create `src/components/ReadingPane.tsx`**

```tsx
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { Book, Highlight, Position } from '../lib/types'
import { chapterAfter, chapterBefore, globalIndex } from '../lib/bible-nav'
import { loadBook, loadRedLetter, type RedLetterMap } from '../lib/bible-data'
import ChapterView from './ChapterView'
import { useAnnotations } from '../state/annotations'

const MAX_CHAPTERS = 12

interface Props {
  target: Position
  navId: number                 // increments on every explicit navigation
  targetVerseRange?: { start: number; end: number } | null
  onPositionChange: (pos: Position) => void
}

export default function ReadingPane({ target, navId, targetVerseRange, onPositionChange }: Props) {
  const [chapters, setChapters] = useState<Position[]>([target])
  const [books, setBooks] = useState<Map<string, Book>>(new Map())
  const [redMap, setRedMap] = useState<RedLetterMap>({})
  const [loadError, setLoadError] = useState(false)
  const scrollerRef = useRef<HTMLDivElement>(null)
  const heightBeforeRef = useRef<number | null>(null)   // set before a prepend/trim-from-front
  const reportedRef = useRef<string>('')
  const { highlights, bookmarks } = useAnnotations()

  // Load red letter map once.
  useEffect(() => { loadRedLetter().then(setRedMap).catch(() => {}) }, [])

  // Ensure every listed chapter's book is loaded.
  useEffect(() => {
    const missing = [...new Set(chapters.map((c) => c.book))].filter((b) => !books.has(b))
    if (!missing.length) return
    let cancelled = false
    Promise.all(missing.map((name) => loadBook(name)))
      .then((loaded) => {
        if (cancelled) return
        setBooks((prev) => { const next = new Map(prev); loaded.forEach((b) => next.set(b.name, b)); return next })
        setLoadError(false)
      })
      .catch(() => !cancelled && setLoadError(true))
    return () => { cancelled = true }
  }, [chapters, books])

  // Reset on explicit navigation.
  useEffect(() => {
    setChapters([target])
    heightBeforeRef.current = null
    const el = scrollerRef.current
    if (el) el.scrollTop = 0
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navId])

  // Scroll-anchor compensation: runs synchronously after prepend/front-trim renders.
  useLayoutEffect(() => {
    const el = scrollerRef.current
    if (el && heightBeforeRef.current != null) {
      el.scrollTop += el.scrollHeight - heightBeforeRef.current
      heightBeforeRef.current = null
    }
  }, [chapters])

  // Scroll handling: sentinel-free edge detection + topmost-chapter tracking.
  useEffect(() => {
    const el = scrollerRef.current
    if (!el) return
    let raf = 0
    const onScroll = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const nearTop = el.scrollTop < 600
        const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 600
        if (nearTop) {
          setChapters((cur) => {
            const prev = chapterBefore(cur[0])
            if (!prev || cur.some((c) => globalIndex(c) === globalIndex(prev))) return cur
            heightBeforeRef.current = el.scrollHeight
            const next = [prev, ...cur]
            return next.length > MAX_CHAPTERS ? next.slice(0, MAX_CHAPTERS) : next
          })
        } else if (nearBottom) {
          setChapters((cur) => {
            const nxt = chapterAfter(cur[cur.length - 1])
            if (!nxt || cur.some((c) => globalIndex(c) === globalIndex(nxt))) return cur
            let next = [...cur, nxt]
            if (next.length > MAX_CHAPTERS) {
              heightBeforeRef.current = el.scrollHeight   // trimming from the front shifts content up
              next = next.slice(next.length - MAX_CHAPTERS)
            }
            return next
          })
        }
        // Topmost visible chapter → position report.
        const secs = el.querySelectorAll<HTMLElement>('.chapter')
        let current: HTMLElement | null = null
        for (const s of secs) {
          if (s.offsetTop <= el.scrollTop + 80) current = s
          else break
        }
        const pick = current ?? secs[0]
        if (pick) {
          const key = `${pick.dataset.book}|${pick.dataset.chapter}`
          if (key !== reportedRef.current) {
            reportedRef.current = key
            onPositionChange({ book: pick.dataset.book!, chapter: Number(pick.dataset.chapter) })
          }
        }
      })
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => { el.removeEventListener('scroll', onScroll); cancelAnimationFrame(raf) }
  }, [onPositionChange, navId])

  // Scroll the target verse into view after a search navigation.
  useEffect(() => {
    if (!targetVerseRange) return
    const el = scrollerRef.current
    const t = setTimeout(() => {
      const v = el?.querySelector(`[data-book="${target.book}"][data-chapter="${target.chapter}"] [data-verse="${targetVerseRange.start}"]`)
      v?.scrollIntoView({ block: 'center' })
    }, 60)
    return () => clearTimeout(t)
  }, [navId, targetVerseRange, target])

  return (
    <div className="reading-pane" ref={scrollerRef}>
      {loadError && (
        <div className="load-error">
          Couldn&apos;t load Scripture text. <button onClick={() => setBooks(new Map(books))}>Retry</button>
        </div>
      )}
      {chapters.map((pos) => {
        const book = books.get(pos.book)
        const ch = book?.chapters.find((c) => c.number === pos.chapter)
        if (!book || !ch) return <div key={`${pos.book}-${pos.chapter}`} className="chapter-placeholder" data-book={pos.book} data-chapter={pos.chapter} />
        const isTargetCh = pos.book === target.book && pos.chapter === target.chapter
        return (
          <ChapterView
            key={`${pos.book}-${pos.chapter}`}
            bookName={pos.book}
            chapter={ch}
            showBookTitle={pos.chapter === 1}
            redVerses={redMap[pos.book]?.[String(pos.chapter)] ?? []}
            highlights={highlights.filter((h) => h.book === pos.book && h.chapter === pos.chapter)}
            bookmarked={bookmarks.some((b) => b.book === pos.book && b.chapter === pos.chapter)}
            targetVerseRange={isTargetCh ? targetVerseRange : null}
          />
        )
      })}
    </div>
  )
}
```

Note: this imports `useAnnotations` from Task 15's context. To keep this task independently testable, create a **stub** `src/state/annotations.tsx` now (Task 15 replaces its internals):

```tsx
import { createContext, useContext, type ReactNode } from 'react'
import type { Highlight, Bookmark, HistoryEntry } from '../lib/types'

export interface AnnotationsCtx {
  highlights: Highlight[]; bookmarks: Bookmark[]; history: HistoryEntry[]
  addHighlight(h: Highlight): void; removeHighlights(book: string, chapter: number, verse: number, startChar: number, endChar: number): void
  toggleBookmark(book: string, chapter: number): void
  logHistory(book: string, chapter: number): void
}
const EMPTY: AnnotationsCtx = {
  highlights: [], bookmarks: [], history: [],
  addHighlight: () => {}, removeHighlights: () => {}, toggleBookmark: () => {}, logHistory: () => {},
}
const Ctx = createContext<AnnotationsCtx>(EMPTY)
export function AnnotationsProvider({ children }: { children: ReactNode }) {
  return <Ctx.Provider value={EMPTY}>{children}</Ctx.Provider>
}
export function useAnnotations() { return useContext(Ctx) }
```

- [ ] **Step 2: Create `src/components/Reader.tsx`**

```tsx
import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import { Navigate, useLocation, useNavigate, useParams } from 'react-router-dom'
import type { Position } from '../lib/types'
import { bookBySlug, slugForPosition } from '../lib/bible-nav'
import ReadingPane from './ReadingPane'
import { useAnnotations } from '../state/annotations'

export interface VerseRange { start: number; end: number }
interface NavCtx { position: Position; jump: (pos: Position, verseRange?: VerseRange) => void }
const Ctx = createContext<NavCtx | null>(null)
export function useNav(): NavCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useNav outside Reader')
  return ctx
}

export default function Reader({ children }: { children?: React.ReactNode }) {
  const { slug, chapter } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const { logHistory } = useAnnotations()

  const info = bookBySlug(slug ?? 'genesis')
  const chNum = Number(chapter ?? 1)
  const valid = info && Number.isInteger(chNum) && chNum >= 1 && chNum <= (info?.chapters ?? 0)
  const target: Position = valid ? { book: info!.name, chapter: chNum } : { book: 'Genesis', chapter: 1 }

  // location.key changes on every push AND back/forward — perfect navId.
  const [navId, setNavId] = useState(0)
  useEffect(() => { setNavId((n) => n + 1) }, [location.key])

  const [position, setPosition] = useState<Position>(target)
  const historyTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const onPositionChange = useCallback((pos: Position) => {
    setPosition(pos)
    // Silent URL update — bypasses the router so ReadingPane doesn't remount.
    const url = `${import.meta.env.BASE_URL}${slugForPosition(pos)}/${pos.chapter}`
    window.history.replaceState(window.history.state, '', url)
    if (historyTimer.current) clearTimeout(historyTimer.current)
    historyTimer.current = setTimeout(() => logHistory(pos.book, pos.chapter), 2000)
  }, [logHistory])

  const jump = useCallback((pos: Position, verseRange?: VerseRange) => {
    navigate(`/${slugForPosition(pos)}/${pos.chapter}`, { state: verseRange ? { verseRange } : undefined })
  }, [navigate])

  if (!valid && slug) return <Navigate to="/genesis/1" replace />
  const verseRange = (location.state as { verseRange?: VerseRange } | null)?.verseRange ?? null

  return (
    <Ctx.Provider value={{ position, jump }}>
      <ReadingPane target={target} navId={navId} targetVerseRange={verseRange} onPositionChange={onPositionChange} />
      {children}
    </Ctx.Provider>
  )
}
```

- [ ] **Step 3: Wire router in `src/main.tsx` and `src/App.tsx`**

`src/main.tsx`:

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import './styles/global.css'
import App from './App.tsx'

const router = createBrowserRouter(
  [{ path: '/:slug?/:chapter?', element: <App /> }],
  { basename: import.meta.env.BASE_URL.replace(/\/$/, '') || '/' },
)
createRoot(document.getElementById('root')!).render(
  <StrictMode><RouterProvider router={router} /></StrictMode>,
)
```

`src/App.tsx` (replaces harness):

```tsx
import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'

export default function App() {
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader />
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
```

Add to `global.css`:

```css
.reading-pane { height: 100vh; overflow-y: auto; overflow-anchor: none; scrollbar-width: none; }
.reading-pane::-webkit-scrollbar { display: none; }
.chapter-placeholder { min-height: 60vh; }
.load-error { max-width: 700px; margin: 12px auto; padding: 10px 16px; border: 1px solid var(--divider); border-radius: 8px; font-family: system-ui, sans-serif; font-size: 13px; }
```

- [ ] **Step 4: Manual verification (the critical one)** — `npm run dev`:
  1. Open `/isaiah/40` → Isaiah 40 renders at top.
  2. Scroll down through 3+ chapters — next chapters append seamlessly, no jumps; crossing into Jeremiah shows its book title.
  3. Scroll UP — previous chapters prepend with **zero visible jump** (the reading position must not shift). This is the acceptance test for the prior jank; do not proceed until it is smooth in Chrome AND Safari.
  4. Keep scrolling 15+ chapters — DOM stays ≤12 `.chapter` sections (check dev tools), no jump when trimming.
  5. URL bar silently updates to the visible chapter; reload restores that chapter; browser Back returns to the previous explicit location.
  6. Invalid URL `/atlantis/9` redirects to `/genesis/1`.

- [ ] **Step 5: Run tests + commit**

```bash
npx vitest run    # all suites PASS
git add -A && git commit -m "feat: infinite-scroll reading pane with anchored prepend and URL sync"
```

---

### Task 11: Scrubber strip (track, thumb, drag)

**Files:**
- Create: `src/components/Scrubber.tsx`
- Modify: `src/components/Reader.tsx` (mount), `src/styles/global.css`

**Interfaces:**
- Consumes: `useNav()` (`position`, `jump`), `globalIndex`, `positionForGlobalIndex`, `TOTAL_CHAPTERS`, `useAnnotations()` (highlights/bookmarks for markers).
- Produces: `Scrubber` — self-positioning fixed right-edge component; exposes hover/drag/preview state to `ScrubberPanel` (Task 12) via props defined there. In this task the panel is not yet rendered.

- [ ] **Step 1: Create `src/components/Scrubber.tsx`**

```tsx
import { useCallback, useEffect, useRef, useState } from 'react'
import { TOTAL_CHAPTERS } from '../lib/bible-index'
import { globalIndex, positionForGlobalIndex } from '../lib/bible-nav'
import { useNav } from './Reader'
import { useAnnotations } from '../state/annotations'

export const TRACK_INSET = 20
export const STRIP_WIDTH = 30

export default function Scrubber() {
  const { position, jump } = useNav()
  const { highlights, bookmarks } = useAnnotations()
  const stripRef = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState(0)
  const [hovered, setHovered] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [dragFraction, setDragFraction] = useState(0)
  const lastNavigated = useRef(-1)

  useEffect(() => {
    const el = stripRef.current
    if (!el) return
    const ro = new ResizeObserver(() => setHeight(el.clientHeight))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const trackHeight = Math.max(0, height - TRACK_INSET * 2)
  const currentFraction = dragging ? dragFraction : globalIndex(position) / (TOTAL_CHAPTERS - 1)
  const thumbY = TRACK_INSET + currentFraction * trackHeight

  const fractionForClientY = useCallback((clientY: number) => {
    const rect = stripRef.current!.getBoundingClientRect()
    const y = clientY - rect.top
    return Math.min(1, Math.max(0, (y - TRACK_INSET) / trackHeight))
  }, [trackHeight])

  const navigateToFraction = useCallback((fraction: number) => {
    const idx = Math.round(fraction * (TOTAL_CHAPTERS - 1))
    if (idx !== lastNavigated.current) {
      lastNavigated.current = idx
      jump(positionForGlobalIndex(idx))
    }
  }, [jump])

  const onPointerDown = (e: React.PointerEvent) => {
    stripRef.current!.setPointerCapture(e.pointerId)
    setDragging(true)
    const f = fractionForClientY(e.clientY)
    setDragFraction(f)
    navigateToFraction(f)
  }
  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragging) return
    const f = fractionForClientY(e.clientY)
    setDragFraction(f)
    navigateToFraction(f)
  }
  const onPointerUp = () => { setDragging(false); lastNavigated.current = -1 }

  const cx = STRIP_WIDTH / 2
  return (
    <div
      ref={stripRef}
      className="scrubber-strip"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerEnter={() => setHovered(true)}
      onPointerLeave={() => setHovered(false)}
    >
      <svg width={STRIP_WIDTH} height={height || 1}>
        <rect x={cx - 1} y={TRACK_INSET} width={2} height={trackHeight} rx={1} className="scrubber-track" />
        {highlights.map((h, i) => {
          const y = TRACK_INSET + (globalIndex({ book: h.book, chapter: h.chapter }) / (TOTAL_CHAPTERS - 1)) * trackHeight
          return <rect key={`h${i}`} x={cx - 8} y={y - 1.5} width={6} height={3} rx={1} className={`tick-${h.color}`} />
        })}
        {bookmarks.map((b, i) => {
          const y = TRACK_INSET + (globalIndex(b) / (TOTAL_CHAPTERS - 1)) * trackHeight
          return <path key={`b${i}`} d={`M ${cx + 3} ${y - 3} L ${cx + 6} ${y} L ${cx + 3} ${y + 3} L ${cx} ${y} Z`} className="scrubber-bookmark" />
        })}
        <rect x={cx - 3} y={thumbY - 15} width={6} height={30} rx={3} className="scrubber-thumb" />
      </svg>
    </div>
  )
}
```

Note: `hovered`/`dragging` look unused in this task — they feed the label panel in Task 12; keep them.

- [ ] **Step 2: Styles + mount**

`global.css`:

```css
.scrubber-strip { position: fixed; top: 0; right: 0; bottom: 0; width: 30px; z-index: 20; cursor: pointer; touch-action: none; }
.scrubber-track { fill: color-mix(in srgb, var(--text-secondary) 30%, transparent); }
.scrubber-thumb { fill: var(--accent); }
.scrubber-bookmark { fill: var(--accent); }
.tick-yellow { fill: #f5c518; } .tick-green { fill: #30d158; } .tick-blue { fill: #0a84ff; }
.tick-pink { fill: #ff375f; } .tick-purple { fill: #bf5af2; }
```

Mount inside `Reader.tsx`'s provider (after `<ReadingPane …/>`): `<Scrubber />` (import it).

- [ ] **Step 3: Manual verification** — `npm run dev`: thumb sits proportionally (Isaiah ≈ 60% down); dragging scrubs smoothly through the whole Bible, reading pane follows chapter-by-chapter (no thrash — navigation fires only on chapter change); releasing and re-dragging works; thumb tracks reading position while scrolling normally.

- [ ] **Step 4: Run tests + commit** — `npx vitest run` PASS; `git add -A && git commit -m "feat: scrubber strip with track, thumb, and drag navigation"`

---

### Task 12: Scrubber label panel + wheel stepping

**Files:**
- Create: `src/components/ScrubberPanel.tsx`
- Modify: `src/components/Scrubber.tsx`, `src/styles/global.css`

**Interfaces:**
- Consumes: `BOOKS`, `TOTAL_CHAPTERS`, `spaceLabels`, scrubber state (hovered/dragging/currentFraction/trackHeight).
- Produces: `ScrubberPanel({ trackHeight, currentFraction, focusedBookIndex, onHoverChange, onSelectBook })` — 180px-wide panel left of the strip; visible prop controlled by Scrubber with 150ms delayed hide.

- [ ] **Step 1: Create `src/components/ScrubberPanel.tsx`**

```tsx
import { useMemo, useState } from 'react'
import { BOOKS, TOTAL_CHAPTERS } from '../lib/bible-index'
import { spaceLabels } from '../lib/label-spacing'
import { STRIP_WIDTH, TRACK_INSET } from './Scrubber'

export const PANEL_WIDTH = 180

interface Props {
  trackHeight: number
  currentFraction: number
  focusedBookIndex: number       // current book, or wheel-preview override
  onHoverChange: (hovering: boolean) => void
  onSelectBook: (bookName: string) => void
}

export default function ScrubberPanel({ trackHeight, currentFraction, focusedBookIndex, onHoverChange, onSelectBook }: Props) {
  const [hoveredRow, setHoveredRow] = useState<number | null>(null)

  const fractions = useMemo(() => {
    const mids = BOOKS.map((b) => (b.start + b.chapters / 2) / TOTAL_CHAPTERS)
    return spaceLabels(mids, trackHeight, 20)
  }, [trackHeight])

  // Translate the whole label stack so the focused book's label aligns with the thumb.
  const thumbY = TRACK_INSET + currentFraction * trackHeight
  const focusedLabelY = TRACK_INSET + fractions[focusedBookIndex] * trackHeight
  const delta = thumbY - focusedLabelY

  const firstY = TRACK_INSET + fractions[0] * trackHeight + delta
  const lastY = TRACK_INSET + fractions[fractions.length - 1] * trackHeight + delta

  return (
    <div
      className="scrubber-panel"
      style={{ right: STRIP_WIDTH + 4, width: PANEL_WIDTH }}
      onPointerEnter={() => onHoverChange(true)}
      onPointerLeave={() => { onHoverChange(false); setHoveredRow(null) }}
    >
      <div className="scrubber-panel-bg" style={{ top: firstY - 12, height: lastY - firstY + 24 }} />
      {BOOKS.map((b, i) => {
        const y = TRACK_INSET + fractions[i] * trackHeight + delta
        const isCurrent = i === focusedBookIndex
        const isHovered = i === hoveredRow
        const distance = Math.abs(i - focusedBookIndex)
        const opacity = isCurrent || isHovered ? 1 : Math.max(0.3, 1 - distance * 0.07)
        return (
          <button
            key={b.name}
            className={`scrubber-label${isCurrent ? ' current' : ''}${isHovered ? ' hovered' : ''}`}
            style={{ top: y - 11, opacity }}
            onPointerEnter={() => setHoveredRow(i)}
            onClick={() => onSelectBook(b.name)}
          >
            {b.name}
          </button>
        )
      })}
    </div>
  )
}
```

- [ ] **Step 2: Integrate into `Scrubber.tsx`**

Add state and handlers (merge with the existing component — final state list: `height, hovered, panelHovered, dragging, dragFraction, wheelBookIndex`):

```tsx
const [panelHovered, setPanelHovered] = useState(false)
const [visible, setVisible] = useState(false)
const [wheelBookIndex, setWheelBookIndex] = useState<number | null>(null)
const hideTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

const showLabels = hovered || dragging || panelHovered
useEffect(() => {
  if (showLabels) {
    if (hideTimer.current) clearTimeout(hideTimer.current)
    setVisible(true)
  } else {
    hideTimer.current = setTimeout(() => { setVisible(false); setWheelBookIndex(null) }, 150)
  }
  return () => { if (hideTimer.current) clearTimeout(hideTimer.current) }
}, [showLabels])

const currentBookIndex = BOOKS.findIndex((b) => b.name === position.book)
const focusedBookIndex = wheelBookIndex ?? Math.max(0, currentBookIndex)

const onWheel = (e: React.WheelEvent) => {
  if (!showLabels) return
  const step = e.deltaY > 0 ? 1 : -1
  setWheelBookIndex((cur) => Math.max(0, Math.min(BOOKS.length - 1, (cur ?? Math.max(0, currentBookIndex)) + step)))
}
```

Render after the `<svg>`, inside the strip's parent fragment (wrap the return in `<>…</>` with the panel outside the 30px strip div):

```tsx
{visible && (
  <ScrubberPanel
    trackHeight={trackHeight}
    currentFraction={currentFraction}
    focusedBookIndex={focusedBookIndex}
    onHoverChange={setPanelHovered}
    onSelectBook={(name) => { jump({ book: name, chapter: 1 }); setWheelBookIndex(null) }}
  />
)}
```

Attach `onWheel={onWheel}` to both the strip div and (inside ScrubberPanel's root via prop pass-through or by lifting) — simplest: put `onWheel` on a fragment-level wrapper `<div className="scrubber-zone" onWheel={onWheel}>` containing both strip and panel.

- [ ] **Step 3: Panel styles**

```css
.scrubber-zone { position: fixed; top: 0; right: 0; bottom: 0; z-index: 20; }
.scrubber-panel { position: fixed; top: 0; bottom: 0; overflow: hidden; z-index: 19; font-family: -apple-system, system-ui, sans-serif; }
.scrubber-panel-bg { position: absolute; left: 0; right: 0; background: var(--overlay-bg); backdrop-filter: blur(14px); border-radius: 8px; box-shadow: -2px 0 8px rgba(0,0,0,0.15); border: 1px solid var(--divider); }
.scrubber-label { position: absolute; left: 0; right: 0; height: 22px; border: none; background: transparent; color: var(--text); font-size: 13px; font-weight: 300; cursor: pointer; white-space: nowrap; text-align: center; border-radius: 11px; transition: opacity 0.1s; }
.scrubber-label.current { font-weight: 600; }
.scrubber-label.hovered { background: var(--hover); font-weight: 500; }
```

Note the strip itself must remain `position: fixed; right: 0; width: 30px` inside `.scrubber-zone` (adjust: make `.scrubber-strip` `position: absolute; right: 0; top: 0; bottom: 0;` now that it lives in the fixed zone).

- [ ] **Step 4: Manual verification** — compare against `~/Projects/Zephyr/docs/bible_scrubber.png` and the running native app if available:
  1. Hover the right edge → panel fades in listing all 66 books; current book semibold, neighbors fading with distance.
  2. Move away → panel lingers 150ms then fades; moving onto the panel keeps it open.
  3. Drag the thumb → book list stays aligned so the focused book tracks the thumb.
  4. Click "Psalms" (or the data's Psalm name) → jumps to its chapter 1.
  5. Wheel over the strip → steps focused book up/down without navigating; click confirms.
  6. Short window (≤600px tall): labels overflow but stay ordered and clipped, focused region always visible near the thumb.

- [ ] **Step 5: Run tests + commit** — `npx vitest run` PASS; `git add -A && git commit -m "feat: scrubber label panel with min-gap spacing, hover, and wheel stepping"`

---

### Task 13: Search overlay

**Files:**
- Create: `src/components/SearchOverlay.tsx`
- Modify: `src/App.tsx` (overlay state lives in App; pass `open`/`onClose` down), `src/styles/global.css`

**Interfaces:**
- Consumes: `parseReference`, `searchVerses`, `loadAllBooks`, `useNav().jump`.
- Produces: `SearchOverlay({ onClose })` — rendered inside `Reader`'s `NavContext` (as a child of `Reader`), so `useNav` works. App holds `const [overlay, setOverlay] = useState<'search'|'toc'|'history'|'settings'|'shortcuts'|null>(null)` and renders overlays as `<Reader>{overlay === 'search' && <SearchOverlay onClose={…} />}…</Reader>`.

- [ ] **Step 1: Create `src/components/SearchOverlay.tsx`**

```tsx
import { useEffect, useRef, useState } from 'react'
import { parseReference } from '../lib/reference-parser'
import { searchVerses, type SearchResult } from '../lib/search'
import { loadAllBooks } from '../lib/bible-data'
import { useNav } from './Reader'
import type { Book } from '../lib/types'

export default function SearchOverlay({ onClose }: { onClose: () => void }) {
  const { jump } = useNav()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [selected, setSelected] = useState(0)
  const [loading, setLoading] = useState<string | null>(null)
  const booksRef = useRef<Book[] | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const ref = parseReference(query)

  useEffect(() => { inputRef.current?.focus() }, [])

  useEffect(() => {
    if (ref || query.trim().length < 3) { setResults([]); return }
    let cancelled = false
    const t = setTimeout(async () => {
      if (!booksRef.current) {
        setLoading('Loading Scripture…')
        booksRef.current = await loadAllBooks((n, total) => setLoading(`Loading Scripture… ${n}/${total}`))
        setLoading(null)
      }
      if (!cancelled) { setResults(searchVerses(query, booksRef.current)); setSelected(0) }
    }, 250)
    return () => { cancelled = true; clearTimeout(t) }
  }, [query])   // eslint-disable-line react-hooks/exhaustive-deps

  const go = (r?: SearchResult) => {
    if (ref) {
      jump({ book: ref.book, chapter: ref.chapter }, ref.verse ? { start: ref.verse, end: ref.verseEnd ?? ref.verse } : undefined)
    } else if (r) {
      jump({ book: r.book, chapter: r.chapter }, { start: r.verse, end: r.verse })
    } else return
    onClose()
  }

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose()
    else if (e.key === 'Enter') go(results[selected])
    else if (e.key === 'ArrowDown') { e.preventDefault(); setSelected((s) => Math.min(results.length - 1, s + 1)) }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setSelected((s) => Math.max(0, s - 1)) }
  }

  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="search-box" onClick={(e) => e.stopPropagation()} onKeyDown={onKeyDown}>
        <input ref={inputRef} value={query} placeholder="Search — “John 3:16” or keywords" onChange={(e) => setQuery(e.target.value)} />
        {ref && <div className="search-ref-hint">↵ Go to {ref.book} {ref.chapter}{ref.verse ? `:${ref.verse}` : ''}{ref.verseEnd ? `–${ref.verseEnd}` : ''}</div>}
        {loading && <div className="search-status">{loading}</div>}
        {!ref && results.length > 0 && (
          <ul className="search-results">
            {results.slice(0, 50).map((r, i) => (
              <li key={`${r.book}${r.chapter}:${r.verse}`} className={i === selected ? 'selected' : ''} onClick={() => go(r)} onMouseEnter={() => setSelected(i)}>
                <span className="result-ref">{r.book} {r.chapter}:{r.verse}</span>
                <span className="result-text">
                  {r.text.slice(Math.max(0, r.matchStart - 30), r.matchStart)}
                  <b>{r.text.slice(r.matchStart, r.matchEnd)}</b>
                  {r.text.slice(r.matchEnd, r.matchEnd + 60)}
                </span>
              </li>
            ))}
          </ul>
        )}
        {!ref && !loading && query.trim().length >= 3 && results.length === 0 && <div className="search-status">No results</div>}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Styles**

```css
.overlay-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.25); z-index: 50; display: flex; justify-content: center; align-items: flex-start; padding-top: 12vh; }
.search-box { width: min(600px, 90vw); background: var(--overlay-bg); backdrop-filter: blur(16px); border-radius: 12px; border: 1px solid var(--divider); box-shadow: 0 16px 50px rgba(0,0,0,0.3); overflow: hidden; font-family: -apple-system, system-ui, sans-serif; }
.search-box input { width: 100%; border: none; outline: none; background: transparent; color: var(--text); font-size: 18px; padding: 16px 18px; }
.search-ref-hint, .search-status { padding: 10px 18px 14px; color: var(--text-secondary); font-size: 13px; }
.search-results { list-style: none; max-height: 50vh; overflow-y: auto; border-top: 1px solid var(--divider); }
.search-results li { padding: 9px 18px; cursor: pointer; display: flex; flex-direction: column; gap: 2px; }
.search-results li.selected { background: var(--hover); }
.result-ref { font-size: 12px; font-weight: 600; color: var(--accent); }
.result-text { font-size: 13px; color: var(--text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
```

- [ ] **Step 3: App overlay state** — in `src/App.tsx`:

```tsx
import { useState } from 'react'
import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'
import SearchOverlay from './components/SearchOverlay'

export type OverlayName = 'search' | 'toc' | 'history' | 'settings' | 'shortcuts' | null

export default function App() {
  const [overlay, setOverlay] = useState<OverlayName>(null)
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader>
          {overlay === 'search' && <SearchOverlay onClose={() => setOverlay(null)} />}
        </Reader>
        <button className="corner-btn" style={{ right: 44 }} title="Search (⌘K)" onClick={() => setOverlay('search')}>&#8981;</button>
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
```

```css
.corner-btn { position: fixed; top: 10px; z-index: 30; border: none; background: transparent; color: var(--text-secondary); font-size: 16px; cursor: pointer; padding: 6px; border-radius: 6px; }
.corner-btn:hover { background: var(--hover); color: var(--text); }
```

- [ ] **Step 4: Manual verification** — open search: type `1 cor 13:4-7` → hint appears, Enter jumps and flashes verses 4–7; type `jars of clay` → first search loads all books with progress, results list with bold match; arrow keys + Enter navigate; second search instant; Esc closes.

- [ ] **Step 5: Run tests + commit** — `npx vitest run` PASS; `git add -A && git commit -m "feat: search overlay with reference jump and keyword search"`

---

### Task 14: TOC overlay

**Files:**
- Create: `src/components/TocOverlay.tsx`
- Modify: `src/App.tsx`, `src/styles/global.css`

**Interfaces:**
- Consumes: `BOOKS`, `useNav()`.
- Produces: `TocOverlay({ onClose })` rendered as a `Reader` child like SearchOverlay; App adds `overlay === 'toc'` case and a corner button.

- [ ] **Step 1: Create `src/components/TocOverlay.tsx`**

```tsx
import { useState } from 'react'
import { BOOKS, type BookInfo } from '../lib/bible-index'
import { useNav } from './Reader'

export default function TocOverlay({ onClose }: { onClose: () => void }) {
  const { position, jump } = useNav()
  const [book, setBook] = useState<BookInfo | null>(null)

  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box" onClick={(e) => e.stopPropagation()}>
        {!book ? (
          <div className="toc-grid">
            {BOOKS.map((b) => (
              <button key={b.name} className={b.name === position.book ? 'toc-item current' : 'toc-item'} onClick={() => setBook(b)}>{b.name}</button>
            ))}
          </div>
        ) : (
          <>
            <button className="toc-back" onClick={() => setBook(null)}>‹ {book.name}</button>
            <div className="toc-grid toc-chapters">
              {Array.from({ length: book.chapters }, (_, i) => i + 1).map((n) => (
                <button key={n} className="toc-item" onClick={() => { jump({ book: book.name, chapter: n }); onClose() }}>{n}</button>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Styles + App wiring** — add `{overlay === 'toc' && <TocOverlay onClose={() => setOverlay(null)} />}` inside `<Reader>`; corner button `☰` at `right: 76`.

```css
.toc-box { width: min(680px, 92vw); max-height: 70vh; overflow-y: auto; background: var(--overlay-bg); backdrop-filter: blur(16px); border-radius: 12px; border: 1px solid var(--divider); box-shadow: 0 16px 50px rgba(0,0,0,0.3); padding: 16px; font-family: -apple-system, system-ui, sans-serif; }
.toc-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 4px; }
.toc-chapters { grid-template-columns: repeat(auto-fill, minmax(48px, 1fr)); }
.toc-item { border: none; background: transparent; color: var(--text); font-size: 13px; padding: 7px 8px; border-radius: 6px; cursor: pointer; text-align: left; }
.toc-chapters .toc-item { text-align: center; }
.toc-item:hover { background: var(--hover); }
.toc-item.current { font-weight: 700; color: var(--accent); }
.toc-back { border: none; background: transparent; color: var(--accent); font-size: 14px; font-weight: 600; cursor: pointer; padding: 4px 8px 12px; }
```

- [ ] **Step 3: Manual verification** — TOC opens, current book bold/accented; book → chapter grid → click 40 jumps and closes.

- [ ] **Step 4: Run tests + commit** — `git add -A && git commit -m "feat: table of contents overlay"`

---

### Task 15: Annotations — highlights via selection toolbar, bookmarks

**Files:**
- Modify: `src/state/annotations.tsx` (replace the stub internals with real state)
- Create: `src/components/SelectionToolbar.tsx`
- Modify: `src/components/Reader.tsx` (mount toolbar), `src/App.tsx` (bookmark corner button), `src/styles/global.css`
- Test: `src/state/annotations.test.tsx`

**Interfaces:**
- Consumes: `storage.ts`, types.
- Produces: the real `AnnotationsCtx` (same signature as the Task 10 stub — no consumer changes): state persists to localStorage; `logHistory` dedupes consecutive entries and caps at 200; `removeHighlights` removes any highlight overlapping the given verse/char range; `toggleBookmark` adds/removes.
- `SelectionToolbar` — global component watching `selectionchange`/`mouseup`; when a selection lies within `.verse` spans of a single chapter it shows a floating bar with 5 color dots + a remove button; computes per-verse char ranges from the DOM Range using each verse span's `data-verse` and text offsets (offset math skips the leading `sup.verse-num` text).

- [ ] **Step 1: Write failing test `src/state/annotations.test.tsx`**

```tsx
import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { AnnotationsProvider, useAnnotations } from './annotations'

beforeEach(() => localStorage.clear())
const wrapper = ({ children }: { children: React.ReactNode }) => <AnnotationsProvider>{children}</AnnotationsProvider>

describe('annotations', () => {
  it('adds and persists highlights', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 0, endChar: 10, color: 'yellow' }))
    expect(result.current.highlights).toHaveLength(1)
    expect(JSON.parse(localStorage.getItem('zephyr.v1.highlights')!)).toHaveLength(1)
  })
  it('removes overlapping highlights only', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => {
      result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 0, endChar: 10, color: 'yellow' })
      result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 20, endChar: 30, color: 'green' })
    })
    act(() => result.current.removeHighlights('John', 3, 16, 5, 8))
    expect(result.current.highlights).toHaveLength(1)
    expect(result.current.highlights[0].color).toBe('green')
  })
  it('toggles bookmarks', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => result.current.toggleBookmark('John', 3))
    expect(result.current.bookmarks).toEqual([{ book: 'John', chapter: 3 }])
    act(() => result.current.toggleBookmark('John', 3))
    expect(result.current.bookmarks).toEqual([])
  })
  it('dedupes consecutive history entries', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => { result.current.logHistory('John', 3); result.current.logHistory('John', 3); result.current.logHistory('John', 4) })
    expect(result.current.history.map((h) => h.chapter)).toEqual([4, 3])
  })
})
```

- [ ] **Step 2: Run to verify failure** — the stub returns empty state → FAIL.

- [ ] **Step 3: Replace `src/state/annotations.tsx` internals**

```tsx
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { KEYS, loadJSON, saveJSON } from '../lib/storage'
import type { Highlight, Bookmark, HistoryEntry } from '../lib/types'

export interface AnnotationsCtx {
  highlights: Highlight[]; bookmarks: Bookmark[]; history: HistoryEntry[]
  addHighlight(h: Highlight): void
  removeHighlights(book: string, chapter: number, verse: number, startChar: number, endChar: number): void
  toggleBookmark(book: string, chapter: number): void
  logHistory(book: string, chapter: number): void
}
const Ctx = createContext<AnnotationsCtx | null>(null)

export function AnnotationsProvider({ children }: { children: ReactNode }) {
  const [highlights, setHighlights] = useState<Highlight[]>(() => loadJSON(KEYS.highlights, []))
  const [bookmarks, setBookmarks] = useState<Bookmark[]>(() => loadJSON(KEYS.bookmarks, []))
  const [history, setHistory] = useState<HistoryEntry[]>(() => loadJSON(KEYS.history, []))

  useEffect(() => saveJSON(KEYS.highlights, highlights), [highlights])
  useEffect(() => saveJSON(KEYS.bookmarks, bookmarks), [bookmarks])
  useEffect(() => saveJSON(KEYS.history, history), [history])

  const value: AnnotationsCtx = {
    highlights, bookmarks, history,
    addHighlight: (h) => setHighlights((cur) => [...cur, h]),
    removeHighlights: (book, chapter, verse, startChar, endChar) =>
      setHighlights((cur) => cur.filter((h) =>
        !(h.book === book && h.chapter === chapter && h.verse === verse && h.startChar < endChar && h.endChar > startChar))),
    toggleBookmark: (book, chapter) =>
      setBookmarks((cur) => cur.some((b) => b.book === book && b.chapter === chapter)
        ? cur.filter((b) => !(b.book === book && b.chapter === chapter))
        : [...cur, { book, chapter }]),
    logHistory: (book, chapter) =>
      setHistory((cur) => {
        if (cur[0]?.book === book && cur[0]?.chapter === chapter) return cur
        return [{ book, chapter, timestamp: Date.now() }, ...cur].slice(0, 200)
      }),
  }
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAnnotations(): AnnotationsCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useAnnotations outside AnnotationsProvider')
  return ctx
}
```

- [ ] **Step 4: Run tests** → PASS.

- [ ] **Step 5: Create `src/components/SelectionToolbar.tsx`**

```tsx
import { useEffect, useState } from 'react'
import { useAnnotations } from '../state/annotations'
import type { HighlightColor } from '../lib/types'

const COLORS: HighlightColor[] = ['yellow', 'green', 'blue', 'pink', 'purple']

interface Target { book: string; chapter: number; ranges: Array<{ verse: number; startChar: number; endChar: number }>; x: number; y: number }

/** Char offset of `node`+`offset` within a verse span's text content, excluding the verse-number sup. */
function offsetInVerse(verseEl: Element, node: Node, offset: number): number {
  const walker = document.createTreeWalker(verseEl, NodeFilter.SHOW_TEXT)
  let total = 0
  while (walker.nextNode()) {
    const t = walker.currentNode as Text
    if (t.parentElement?.closest('sup.verse-num')) continue
    if (t === node) return total + offset
    total += t.length
  }
  return total
}

function computeTarget(): Target | null {
  const sel = window.getSelection()
  if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null
  const range = sel.getRangeAt(0)
  const startVerse = (range.startContainer.parentElement)?.closest('.verse')
  const endVerse = (range.endContainer.parentElement)?.closest('.verse')
  if (!startVerse || !endVerse) return null
  const chapterEl = startVerse.closest<HTMLElement>('.chapter')
  if (!chapterEl || endVerse.closest('.chapter') !== chapterEl) return null

  const verses = [...chapterEl.querySelectorAll<HTMLElement>('.verse')]
  const si = verses.indexOf(startVerse as HTMLElement), ei = verses.indexOf(endVerse as HTMLElement)
  if (si < 0 || ei < 0) return null
  const ranges = [] as Target['ranges']
  for (let i = si; i <= ei; i++) {
    const v = verses[i]
    const verse = Number(v.dataset.verse)
    const textLen = [...(function* () { const w = document.createTreeWalker(v, NodeFilter.SHOW_TEXT); while (w.nextNode()) { const t = w.currentNode as Text; if (!t.parentElement?.closest('sup.verse-num')) yield t.length } })()].reduce((a, b) => a + b, 0)
    const startChar = i === si ? offsetInVerse(v, range.startContainer, range.startOffset) : 0
    const endChar = i === ei ? offsetInVerse(v, range.endContainer, range.endOffset) : textLen
    if (endChar > startChar) ranges.push({ verse, startChar, endChar })
  }
  if (!ranges.length) return null
  const rect = range.getBoundingClientRect()
  return { book: chapterEl.dataset.book!, chapter: Number(chapterEl.dataset.chapter), ranges, x: rect.left + rect.width / 2, y: rect.top }
}

export default function SelectionToolbar() {
  const { addHighlight, removeHighlights } = useAnnotations()
  const [target, setTarget] = useState<Target | null>(null)

  useEffect(() => {
    const onUp = () => setTimeout(() => setTarget(computeTarget()), 10)
    const onDown = (e: MouseEvent) => { if (!(e.target as Element).closest('.selection-toolbar')) setTarget(null) }
    document.addEventListener('mouseup', onUp)
    document.addEventListener('mousedown', onDown)
    return () => { document.removeEventListener('mouseup', onUp); document.removeEventListener('mousedown', onDown) }
  }, [])

  if (!target) return null
  const apply = (color: HighlightColor) => {
    for (const r of target.ranges) addHighlight({ book: target.book, chapter: target.chapter, ...r, color })
    window.getSelection()?.removeAllRanges()
    setTarget(null)
  }
  const remove = () => {
    for (const r of target.ranges) removeHighlights(target.book, target.chapter, r.verse, r.startChar, r.endChar)
    window.getSelection()?.removeAllRanges()
    setTarget(null)
  }
  return (
    <div className="selection-toolbar" style={{ left: target.x, top: Math.max(8, target.y - 44) }}>
      {COLORS.map((c) => <button key={c} className={`dot dot-${c}`} onClick={() => apply(c)} title={`Highlight ${c}`} />)}
      <button className="dot dot-remove" onClick={remove} title="Remove highlight">✕</button>
    </div>
  )
}
```

```css
.selection-toolbar { position: fixed; transform: translateX(-50%); display: flex; gap: 6px; background: var(--overlay-bg); backdrop-filter: blur(12px); border: 1px solid var(--divider); border-radius: 999px; padding: 6px 10px; z-index: 60; box-shadow: 0 6px 20px rgba(0,0,0,0.25); }
.dot { width: 20px; height: 20px; border-radius: 50%; border: none; cursor: pointer; font-size: 11px; color: var(--text); }
.dot-yellow { background: #f5c518; } .dot-green { background: #30d158; } .dot-blue { background: #0a84ff; }
.dot-pink { background: #ff375f; } .dot-purple { background: #bf5af2; }
.dot-remove { background: var(--hover); }
```

- [ ] **Step 6: Mount + bookmark button** — in `Reader.tsx` render `<SelectionToolbar />` inside the provider. In `App.tsx` add a bookmark corner button (`right: 12`) — it needs the current position, so move it into `Reader`'s children or read via a small component using `useNav()` + `useAnnotations()`:

```tsx
function BookmarkButton() {
  const { position } = useNav()
  const { bookmarks, toggleBookmark } = useAnnotations()
  const active = bookmarks.some((b) => b.book === position.book && b.chapter === position.chapter)
  return <button className="corner-btn" style={{ right: 12 }} title="Bookmark (⌘D)" onClick={() => toggleBookmark(position.book, position.chapter)}>{active ? '⚑' : '⚐'}</button>
}
```

Render `<BookmarkButton />` as a `Reader` child. Shift search/TOC buttons to `right: 44` / `right: 76` (they must also live inside `Reader`'s children to use context — move all corner buttons there).

- [ ] **Step 7: Manual verification** — select words within one verse → toolbar appears → yellow → highlight renders and survives reload; select across 3 verses → all get per-verse highlights; remove clears only overlapping ones; highlight tick appears on the scrubber; bookmark flag toggles by the drop cap and diamond appears on scrubber.

- [ ] **Step 8: Run tests + commit** — `npx vitest run` PASS; `git add -A && git commit -m "feat: highlights via selection toolbar, bookmarks, persisted annotations"`

---

### Task 16: History overlay, keyboard shortcuts, shortcuts overlay

**Files:**
- Create: `src/components/HistoryOverlay.tsx`, `src/components/ShortcutsOverlay.tsx`, `src/hooks/useKeyboardShortcuts.ts`
- Modify: `src/App.tsx`, `src/components/Reader.tsx`, `src/styles/global.css`

**Interfaces:**
- Consumes: `useAnnotations().history`, `useNav()`, `chapterAfter/chapterBefore`, App's `setOverlay`.
- Produces: `useKeyboardShortcuts({ setOverlay })` — a hook mounted inside `Reader` children; ignores events when `e.target` is an input/textarea or an overlay is open (except Escape).

- [ ] **Step 1: Create `src/hooks/useKeyboardShortcuts.ts`**

```ts
import { useEffect } from 'react'
import { chapterAfter, chapterBefore } from '../lib/bible-nav'
import { useNav } from '../components/Reader'
import { useAnnotations } from '../state/annotations'
import type { OverlayName } from '../App'

export function useKeyboardShortcuts(overlay: OverlayName, setOverlay: (o: OverlayName) => void) {
  const { position, jump } = useNav()
  const { toggleBookmark } = useAnnotations()

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName
      if (e.key === 'Escape') { setOverlay(null); return }
      if (tag === 'INPUT' || tag === 'TEXTAREA' || overlay) return
      const mod = e.metaKey || e.ctrlKey
      if (mod && e.key === 'k') { e.preventDefault(); setOverlay('search') }
      else if (mod && e.key === 'd') { e.preventDefault(); toggleBookmark(position.book, position.chapter) }
      else if (!mod && e.key === '/') { e.preventDefault(); setOverlay('search') }
      else if (!mod && e.key === 't') setOverlay('toc')
      else if (!mod && e.key === 'h') setOverlay('history')
      else if (!mod && e.key === '?') setOverlay('shortcuts')
      else if (e.key === 'ArrowRight') { const n = chapterAfter(position); if (n) jump(n) }
      else if (e.key === 'ArrowLeft') { const p = chapterBefore(position); if (p) jump(p) }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [overlay, setOverlay, position, jump, toggleBookmark])
}
```

- [ ] **Step 2: Create `src/components/HistoryOverlay.tsx`**

```tsx
import { useAnnotations } from '../state/annotations'
import { useNav } from './Reader'

export default function HistoryOverlay({ onClose }: { onClose: () => void }) {
  const { history } = useAnnotations()
  const { jump } = useNav()
  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box" onClick={(e) => e.stopPropagation()}>
        {history.length === 0 && <div className="search-status">No reading history yet</div>}
        <ul className="history-list">
          {history.map((h, i) => (
            <li key={i} onClick={() => { jump({ book: h.book, chapter: h.chapter }); onClose() }}>
              <span>{h.book} {h.chapter}</span>
              <span className="history-date">{new Date(h.timestamp).toLocaleDateString()}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create `src/components/ShortcutsOverlay.tsx`**

```tsx
const ROWS: Array<[string, string]> = [
  ['⌘K or /', 'Search'], ['←  →', 'Previous / next chapter'], ['t', 'Table of contents'],
  ['h', 'Reading history'], ['⌘D', 'Bookmark chapter'], ['?', 'This overlay'], ['Esc', 'Close overlays'],
]
export default function ShortcutsOverlay({ onClose }: { onClose: () => void }) {
  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box shortcuts-box" onClick={(e) => e.stopPropagation()}>
        <table>{ROWS.map(([k, d]) => <tr key={k}><td className="key">{k}</td><td>{d}</td></tr>)}</table>
      </div>
    </div>
  )
}
```

```css
.history-list { list-style: none; }
.history-list li { display: flex; justify-content: space-between; padding: 8px 10px; border-radius: 6px; cursor: pointer; font-size: 14px; }
.history-list li:hover { background: var(--hover); }
.history-date { color: var(--text-secondary); font-size: 12px; }
.shortcuts-box table { width: 100%; border-collapse: collapse; font-size: 14px; }
.shortcuts-box td { padding: 7px 10px; }
.shortcuts-box .key { font-family: ui-monospace, monospace; color: var(--accent); width: 110px; }
```

- [ ] **Step 4: Wire everything in App/Reader** — App passes `overlay`/`setOverlay` into a small `ReaderChrome` component rendered as `Reader`'s child; `ReaderChrome` calls `useKeyboardShortcuts(overlay, setOverlay)` and renders all overlays + corner buttons (settings gear `⚙` opens `SettingsPopover` as `overlay === 'settings'`). Final corner buttons right-to-left: bookmark (12), search (44), TOC (76), history (108), settings (140).

- [ ] **Step 5: Manual verification** — every shortcut works; typing in search box doesn't trigger shortcuts; `←/→` navigates including across books; `h` shows visited chapters after some browsing; settings gear opens the popover.

- [ ] **Step 6: Run tests + commit** — `npx vitest run` PASS; `git add -A && git commit -m "feat: history overlay, keyboard shortcuts, shortcuts cheat sheet"`

---

### Task 17: ESV attribution, SPA fallback, deploy workflow

**Files:**
- Create: `.github/workflows/deploy.yml`, `README.md`
- Modify: `src/App.tsx` (attribution line), `vite.config.ts` (no change expected — verify), `package.json`

**Interfaces:**
- Consumes: a repo secret `DEPLOY_TOKEN` (fine-grained PAT with write access to `jonyen/jonyen.github.io`) — the user must create this; the workflow fails gracefully without it.
- Produces: pushes to `main` publish the built app to `jonyen.github.io/zephyr/` → served at `https://jonyen.com/zephyr/`.

- [ ] **Step 1: Attribution footer** — in the reading pane (bottom of `ReadingPane`'s scroller, after the chapter list):

```tsx
<footer className="esv-attribution">
  Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway. Used by permission. All rights reserved.
</footer>
```

```css
.esv-attribution { max-width: 700px; margin: 0 auto; padding: 24px 32px 40px; color: var(--text-secondary); font-size: 11px; font-family: -apple-system, system-ui, sans-serif; }
```

- [ ] **Step 2: SPA fallback for Pages** — add to `package.json` scripts: `"build": "tsc -b && vite build && cp dist/index.html dist/404.html"`.

- [ ] **Step 3: Create `.github/workflows/deploy.yml`**

```yaml
name: Deploy to jonyen.com/zephyr
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm test
      - run: npm run build
      - name: Publish to jonyen.github.io/zephyr
        uses: peaceiris/actions-gh-pages@v4
        with:
          personal_token: ${{ secrets.DEPLOY_TOKEN }}
          external_repository: jonyen/jonyen.github.io
          publish_branch: main
          publish_dir: ./dist
          destination_dir: zephyr
```

- [ ] **Step 4: Write `README.md`**

```markdown
# Zephyr Web

A web version of [Zephyr](https://github.com/jonyen/zephyr), the minimalist ESV Bible reader for macOS. No accounts, no tracking — highlights, bookmarks, and history live in your browser's localStorage.

Live at [jonyen.com/zephyr](https://jonyen.com/zephyr).

## Develop

    npm install
    npm run dev        # http://localhost:5173
    npm test           # vitest
    npm run build      # production build with /zephyr/ base

## Deploy

Pushes to `main` build and publish `dist/` into `jonyen/jonyen.github.io` under `/zephyr/` via GitHub Actions (requires the `DEPLOY_TOKEN` repo secret — a fine-grained PAT with write access to that repo).
```

- [ ] **Step 5: Verify production build locally**

```bash
npm run build
npx vite preview --base /zephyr/
```
Open the preview URL + `/zephyr/isaiah/40` — app loads with correct asset paths and data fetches under `/zephyr/data/…`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: ESV attribution, SPA fallback, GitHub Pages deploy workflow"
```

- [ ] **Step 7: Manual deploy setup (user action required)** — tell the user: create a fine-grained PAT with `contents: write` on `jonyen/jonyen.github.io`, add it as the `DEPLOY_TOKEN` secret on the zephyr-web GitHub repo, then push `main`. If zephyr-web has no GitHub remote yet, create the repo and push first.

---

## Final Verification (after all tasks)

1. `npx vitest run` — every suite green.
2. `npm run build` — clean production build.
3. Full manual pass in Chrome and Safari against the native app: reading Isaiah 40 side by side (typography, poetry), scrubber feel (hover panel, drag, wheel), search (`1 cor 13:4-7`, "jars of clay"), highlight + reload, bookmark + scrubber diamond, all 5 themes, all 3 fonts, red letter in Matthew 5, bionic toggle, every keyboard shortcut, browser back/forward, deep-link reload.
4. Confirm localStorage contains only `zephyr.v1.*` keys and no network requests besides `data/*.json`.
```
