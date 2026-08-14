export interface MacRelease {
  version: string
  dmgURL: string
}

// The update feed the macOS app's own updater reads. It is a SIBLING of this app's
// deployed directory — public/zephyr-updates/ next to public/zephyr/ — so this path is
// root-relative, not BASE_URL-relative. See the release workflow's "Publish update feed"
// step. It does not exist under `npm run dev`, where this fetch 404s and the link hides.
const MANIFEST_URL = '/zephyr-updates/manifest.json'

// Structural, rather than lib.dom's Navigator, for two reasons: userAgentData is not in
// TypeScript's DOM lib yet, and tests pass plain object literals.
interface NavigatorLike {
  platform?: string
  userAgent?: string
  maxTouchPoints?: number
  userAgentData?: { platform?: string }
}

export function isMacDesktop(nav: NavigatorLike = navigator): boolean {
  // iPadOS reports itself as MacIntel in Safari's desktop mode, and cannot open a DMG.
  // No Mac desktop reports touch points, so this separates them cleanly.
  if ((nav.maxTouchPoints ?? 0) > 0) return false
  const platform = nav.userAgentData?.platform || nav.platform || nav.userAgent || ''
  return /mac/i.test(platform)
}

let cache: Promise<MacRelease | null> | null = null

export function loadMacRelease(): Promise<MacRelease | null> {
  // Deliberately not cleared on failure, unlike bible-data's loadRedLetter: a book the
  // reader needs is worth retrying, an optional download link is not.
  if (!cache) cache = fetchRelease()
  return cache
}

async function fetchRelease(): Promise<MacRelease | null> {
  try {
    const res = await fetch(MANIFEST_URL)
    if (!res.ok) return null
    const m: unknown = await res.json()
    if (typeof m !== 'object' || m === null) return null
    const { version, dmgURL } = m as Partial<MacRelease>
    if (typeof version !== 'string' || typeof dmgURL !== 'string') return null
    return { version, dmgURL }
  } catch {
    return null
  }
}

export function _resetCacheForTests(): void {
  cache = null
}
