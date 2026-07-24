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
    expect(parseReference('  II Tim. 2:15 ')).toEqual({ book: '2 Timothy', chapter: 2, verse: 15 })
  })
  it('handles books starting with i (isaiah)', () => {
    expect(parseReference('isaiah 40')).toEqual({ book: 'Isaiah', chapter: 40 })
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
