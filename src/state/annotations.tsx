import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { KEYS, loadJSON, saveJSON } from '../lib/storage'
import { bookByName } from '../lib/bible-nav'
import type { Highlight, Bookmark, HistoryEntry, HighlightColor } from '../lib/types'

const HIGHLIGHT_COLORS: HighlightColor[] = ['yellow', 'green', 'blue', 'pink', 'purple']

// Loaded storage is untrusted (hand-edited, stale schema, corrupted) — sanitize on load so a
// bad entry can never brick rendering downstream. Spec: "never block reading."
function sanitizeHighlights(v: unknown): Highlight[] {
  if (!Array.isArray(v)) return []
  return v.filter((h): h is Highlight =>
    !!h && typeof h === 'object' &&
    bookByName((h as Highlight).book) != null &&
    Number.isFinite((h as Highlight).chapter) &&
    Number.isFinite((h as Highlight).verse) &&
    Number.isFinite((h as Highlight).startChar) &&
    Number.isFinite((h as Highlight).endChar) &&
    HIGHLIGHT_COLORS.includes((h as Highlight).color))
}

function sanitizeBookmarks(v: unknown): Bookmark[] {
  if (!Array.isArray(v)) return []
  return v.filter((b): b is Bookmark =>
    !!b && typeof b === 'object' &&
    bookByName((b as Bookmark).book) != null &&
    Number.isFinite((b as Bookmark).chapter))
}

function sanitizeHistory(v: unknown): HistoryEntry[] {
  if (!Array.isArray(v)) return []
  return v.filter((h): h is HistoryEntry =>
    !!h && typeof h === 'object' &&
    bookByName((h as HistoryEntry).book) != null &&
    Number.isFinite((h as HistoryEntry).chapter) &&
    Number.isFinite((h as HistoryEntry).timestamp))
}

export interface AnnotationsCtx {
  highlights: Highlight[]; bookmarks: Bookmark[]; history: HistoryEntry[]
  addHighlight(h: Highlight): void
  removeHighlights(book: string, chapter: number, verse: number, startChar: number, endChar: number): void
  toggleBookmark(book: string, chapter: number): void
  logHistory(book: string, chapter: number): void
}
const Ctx = createContext<AnnotationsCtx | null>(null)

export function AnnotationsProvider({ children }: { children: ReactNode }) {
  const [highlights, setHighlights] = useState<Highlight[]>(() => sanitizeHighlights(loadJSON(KEYS.highlights, [])))
  const [bookmarks, setBookmarks] = useState<Bookmark[]>(() => sanitizeBookmarks(loadJSON(KEYS.bookmarks, [])))
  const [history, setHistory] = useState<HistoryEntry[]>(() => sanitizeHistory(loadJSON(KEYS.history, [])))

  useEffect(() => saveJSON(KEYS.highlights, highlights), [highlights])
  useEffect(() => saveJSON(KEYS.bookmarks, bookmarks), [bookmarks])
  useEffect(() => saveJSON(KEYS.history, history), [history])

  const value: AnnotationsCtx = useMemo(() => ({
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
  }), [highlights, bookmarks, history])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAnnotations(): AnnotationsCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useAnnotations outside AnnotationsProvider')
  return ctx
}
