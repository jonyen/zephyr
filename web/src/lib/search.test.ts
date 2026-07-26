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
