import { describe, it, expect, vi, beforeEach } from 'vitest'
import { isMacDesktop, loadMacRelease, _resetCacheForTests } from './mac-download'

// A real manifest, copied from https://jonyen.com/zephyr-updates/manifest.json.
// Only version and dmgURL are consumed; the rest is the macOS updater's business.
const MANIFEST = {
  version: '0.9.9',
  notes: '## What’s New\n\n* Enhanced update security.',
  zipURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.app.zip',
  dmgURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg',
  signature: 'iWdBBG9VduLesHSmrPfBd+h5USwOihIamNPk29QRtjZDjP3nHkffXZvHSqMTyTa5o/1/uFXZrjJeA7oZ6wR/Bw==',
  publishedAt: '2026-07-31T15:11:22Z',
}

const MAC = { platform: 'MacIntel', maxTouchPoints: 0 }
const MAC_VIA_UA_DATA = { userAgentData: { platform: 'macOS' }, platform: '', maxTouchPoints: 0 }
const WINDOWS = { platform: 'Win32', maxTouchPoints: 0 }
const IPHONE = { platform: 'iPhone', userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)', maxTouchPoints: 5 }
// Safari's desktop mode on iPadOS reports MacIntel. It cannot open a DMG.
const IPAD_IN_DESKTOP_MODE = { platform: 'MacIntel', maxTouchPoints: 5 }

const okResponse = (body: unknown) => vi.fn(async () => ({ ok: true, json: async () => body }))

beforeEach(() => {
  _resetCacheForTests()
  vi.unstubAllGlobals()
})

describe('isMacDesktop', () => {
  it('is true for a Mac desktop', () => {
    expect(isMacDesktop(MAC)).toBe(true)
  })
  it('is true when only userAgentData.platform is present', () => {
    expect(isMacDesktop(MAC_VIA_UA_DATA)).toBe(true)
  })
  it('is false on Windows', () => {
    expect(isMacDesktop(WINDOWS)).toBe(false)
  })
  it('is false on iPhone', () => {
    expect(isMacDesktop(IPHONE)).toBe(false)
  })
  it('is false on an iPad reporting itself as a Mac', () => {
    expect(isMacDesktop(IPAD_IN_DESKTOP_MODE)).toBe(false)
  })
})

describe('loadMacRelease', () => {
  it('returns version and dmgURL from the manifest', async () => {
    vi.stubGlobal('fetch', okResponse(MANIFEST))
    expect(await loadMacRelease()).toEqual({
      version: '0.9.9',
      dmgURL: 'https://jonyen.com/zephyr-updates/Zephyr-0.9.9.dmg',
    })
    expect(fetch).toHaveBeenCalledWith('/zephyr-updates/manifest.json')
  })

  it('returns null on a non-2xx response', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ ok: false, status: 404, json: async () => ({}) })))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the fetch throws', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new Error('offline') }))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the manifest has no dmgURL', async () => {
    vi.stubGlobal('fetch', okResponse({ version: '0.9.9' }))
    expect(await loadMacRelease()).toBeNull()
  })

  it('returns null when the manifest is not an object', async () => {
    vi.stubGlobal('fetch', okResponse(null))
    expect(await loadMacRelease()).toBeNull()
  })

  it('memoizes: a second call does not refetch', async () => {
    vi.stubGlobal('fetch', okResponse(MANIFEST))
    await loadMacRelease()
    await loadMacRelease()
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})
