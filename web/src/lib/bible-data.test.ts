import { describe, it, expect, vi, beforeEach } from 'vitest'
import { loadBook, loadAllBooks, loadHeadings, loadParagraphStarts, loadRedLetter, _resetCacheForTests } from './bible-data'

const fakeBook = { name: 'Genesis', chapters: [{ number: 1, verses: [{ number: 1, text: 'In the beginning' }] }] }

function stubFor(url: string) {
  if (url.includes('red_letter')) return { Matthew: { '3': [15] } }
  if (url.includes('paragraph_starts')) return { Matthew: { '7': [1, 6, 7, 12] } }
  if (url.includes('headings')) {
    return { Matthew: { '6': { headings: [{ verse: 1, text: 'Giving to the Needy' }] } },
             Psalms: { '23': { title: 'A Psalm of David.', headings: [] } } }
  }
  return fakeBook
}

beforeEach(() => {
  _resetCacheForTests()
  vi.stubGlobal('fetch', vi.fn(async (url: string) => ({ ok: true, json: async () => stubFor(String(url)) })))
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
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({ ok: true, json: async () => stubFor(String(url)) })))
    const rl = await loadRedLetter()
    expect(rl.Matthew['3']).toEqual([15])
  })
  it('loads paragraph starts', async () => {
    const p = await loadParagraphStarts()
    expect(p.Matthew['7']).toEqual([1, 6, 7, 12])
  })
  it('memoizes paragraph starts', async () => {
    await loadParagraphStarts()
    await loadParagraphStarts()
    expect((globalThis.fetch as ReturnType<typeof vi.fn>).mock.calls.length).toBe(1)
  })
  it('loads headings', async () => {
    const h = await loadHeadings()
    expect(h.Matthew['6'].headings).toEqual([{ verse: 1, text: 'Giving to the Needy' }])
  })
  it('loads a psalm superscription', async () => {
    expect((await loadHeadings()).Psalms['23'].title).toBe('A Psalm of David.')
  })
  it('retries headings after a failed load', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 500 })))
    await expect(loadHeadings()).rejects.toThrow('500')
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({ ok: true, json: async () => stubFor(String(url)) })))
    expect((await loadHeadings()).Matthew['6'].headings).toHaveLength(1)
  })
  it('retries paragraph starts after a failed load', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 500 })))
    await expect(loadParagraphStarts()).rejects.toThrow('500')
    vi.stubGlobal('fetch', vi.fn(async (url: string) => ({ ok: true, json: async () => stubFor(String(url)) })))
    expect((await loadParagraphStarts()).Matthew['7']).toEqual([1, 6, 7, 12])
  })
})
