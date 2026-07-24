import { describe, it, expect } from 'vitest'
import { verseSegments } from './verse-segments'
import type { Highlight, HighlightColor } from './types'

function hl(startChar: number, endChar: number, color: HighlightColor): Highlight {
  return { book: 'B', chapter: 1, verse: 1, startChar, endChar, color }
}

describe('verseSegments', () => {
  it('returns one segment for plain text with no highlights and no bionic', () => {
    expect(verseSegments('just text', [], false)).toEqual([{ text: 'just text' }])
  })

  it('splits at a simple highlight subrange', () => {
    expect(verseSegments('hello', [hl(1, 3, 'green')], false)).toEqual([
      { text: 'h' },
      { text: 'el', color: 'green' },
      { text: 'lo' },
    ])
  })

  it('bolds ~40% of each word when bionic is on, no highlights', () => {
    expect(verseSegments('beginning', [], true)).toEqual([
      { text: 'begi', bold: true },
      { text: 'nning' },
    ])
  })

  it('splits bold range at a highlight boundary mid-word, keeping bold ratio computed on the full word', () => {
    // 'beginning' -> bold = 'begi' (4 chars, ceil(9*0.4)=4), highlight covers chars 0-2 ('be')
    expect(verseSegments('beginning', [hl(0, 2, 'yellow')], true)).toEqual([
      { text: 'be', bold: true, color: 'yellow' },
      { text: 'gi', bold: true },
      { text: 'nning' },
    ])
  })

  it('clamps out-of-bounds highlights without crashing', () => {
    expect(verseSegments('hi', [hl(-5, 1000, 'pink')], false)).toEqual([
      { text: 'hi', color: 'pink' },
    ])
  })

  it('resolves overlapping highlights in favor of the later one in the array', () => {
    expect(verseSegments('hello', [hl(0, 5, 'yellow'), hl(0, 5, 'blue')], false)).toEqual([
      { text: 'hello', color: 'blue' },
    ])
  })
})
