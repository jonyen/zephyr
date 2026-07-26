import { describe, it, expect, beforeEach } from 'vitest'
import { KEYS, loadJSON, saveJSON } from './storage'

beforeEach(() => localStorage.clear())

describe('storage', () => {
  it('round-trips values', () => {
    saveJSON(KEYS.bookmarks, [{ book: 'John', chapter: 3 }])
    expect(loadJSON(KEYS.bookmarks, [])).toEqual([{ book: 'John', chapter: 3 }])
  })
  it('returns fallback when missing', () => {
    expect(loadJSON(KEYS.history, [])).toEqual([])
  })
  it('returns fallback on corrupted JSON', () => {
    localStorage.setItem(KEYS.prefs, '{not json')
    expect(loadJSON(KEYS.prefs, { theme: 'system' })).toEqual({ theme: 'system' })
  })
  it('uses zephyr.v1 prefix', () => {
    expect(Object.values(KEYS).every((k) => k.startsWith('zephyr.v1.'))).toBe(true)
  })
})
