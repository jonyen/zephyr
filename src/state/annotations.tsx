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
