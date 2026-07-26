import { describe, it, expect, vi, beforeEach } from 'vitest'
import { loadBook, loadAllBooks, loadRedLetter, _resetCacheForTests } from './bible-data'

const fakeBook = { name: 'Genesis', chapters: [{ number: 1, verses: [{ number: 1, text: 'In the beginning' }] }] }

beforeEach(() => {
  _resetCacheForTests()
  vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
    ok: true,
    json: async () => (String(url).includes('red_letter') ? { Matthew: { '3': [15] } } : fakeBook),
  })))
})

describe('bible-data', () => {
  it('fetches a book by display name from BASE_URL/data', async () => {
    const b = await loadBook('Genesis')
    expect(b.name).toBe('Genesis')
    expect(fetch).toHaveBeenCalledWith(expect.stringContaining('data/Genesis.json'))
  })
  it('memoizes: second load does not refetch', async () => {
    await loadBook('Genesis')
    await loadBook('Genesis')
    expect(fetch).toHaveBeenCalledTimes(1)
  })
  it('rejects on unknown book', async () => {
    await expect(loadBook('Atlantis')).rejects.toThrow()
  })
  it('rejects on HTTP failure', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 404 })))
    await expect(loadBook('Genesis')).rejects.toThrow('404')
  })
  it('loads all books with progress', async () => {
    const ticks: number[] = []
    const all = await loadAllBooks((n) => ticks.push(n))
    expect(all).toHaveLength(66)
    expect(ticks.at(-1)).toBe(66)
  })
  it('loads red letter map', async () => {
    const rl = await loadRedLetter()
    expect(rl.Matthew['3']).toEqual([15])
  })
  it('retries red letter map after failed load', async () => {
    // First call fails
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 500 })))
    await expect(loadRedLetter()).rejects.toThrow('500')
    // Second call succeeds (stub replaced)
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({
      ok: true,
      json: async () => (String(url).includes('red_letter') ? { Matthew: { '3': [15] } } : fakeBook),
    })))
    const rl = await loadRedLetter()
    expect(rl.Matthew['3']).toEqual([15])
  })
})
