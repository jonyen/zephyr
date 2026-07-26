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
