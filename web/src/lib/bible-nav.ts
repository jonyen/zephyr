import { BOOKS, TOTAL_CHAPTERS, type BookInfo } from './bible-index'
import type { Position } from './types'

const byName = new Map(BOOKS.map((b) => [b.name, b]))
const bySlug = new Map(BOOKS.map((b) => [b.slug, b]))

export function bookByName(name: string): BookInfo | undefined { return byName.get(name) }
export function bookBySlug(slug: string): BookInfo | undefined { return bySlug.get(slug) }

// Singular spellings people type for a book whose slug is plural. A link to
// /psalm/23 should land on Psalm 23, not bounce to Genesis 1.
const SLUG_ALIASES: Record<string, string> = { psalm: 'psalms', proverb: 'proverbs' }

/** The canonical slug for an alias, or undefined if `slug` is not one. */
export function aliasedSlug(slug: string): string | undefined {
  return SLUG_ALIASES[slug.toLowerCase()]
}

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
