import { BOOKS } from './bible-index'
import { bookByName } from './bible-nav'
import type { Book } from './types'

export type RedLetterMap = Record<string, Record<string, number[]>>
/** Book -> chapter -> the verses that open a paragraph, from the ESV's layout. */
export type ParagraphMap = Record<string, Record<string, number[]>>

const dataUrl = (file: string) => `${import.meta.env.BASE_URL}data/${file}`

let bookCache = new Map<string, Promise<Book>>()
let redLetterCache: Promise<RedLetterMap> | null = null
let paragraphCache: Promise<ParagraphMap> | null = null

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
  if (!redLetterCache) {
    redLetterCache = fetchJSON<RedLetterMap>(dataUrl('red_letter_verses.json'))
    redLetterCache.catch(() => { redLetterCache = null })
  }
  return redLetterCache
}

export function loadParagraphStarts(): Promise<ParagraphMap> {
  if (!paragraphCache) {
    paragraphCache = fetchJSON<ParagraphMap>(dataUrl('paragraph_starts.json'))
    paragraphCache.catch(() => { paragraphCache = null })
  }
  return paragraphCache
}

export function _resetCacheForTests(): void {
  bookCache = new Map()
  redLetterCache = null
  paragraphCache = null
}
