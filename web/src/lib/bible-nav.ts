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
