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
