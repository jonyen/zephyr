import { describe, it, expect } from 'vitest'
import { bionicWords } from './bionic'

describe('bionicWords', () => {
  it('bolds ~40% of each word', () => {
    expect(bionicWords('beginning')).toEqual([{ bold: 'begi', rest: 'nning' }])
  })
  it('keeps whitespace attached', () => {
    expect(bionicWords('in the')).toEqual([{ bold: 'i', rest: 'n ' }, { bold: 'th', rest: 'e' }])
  })
  it('handles empty text', () => {
    expect(bionicWords('')).toEqual([])
  })
})
