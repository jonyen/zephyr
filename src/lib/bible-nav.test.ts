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
