export const KEYS = {
  highlights: 'zephyr.v1.highlights',
  bookmarks: 'zephyr.v1.bookmarks',
  history: 'zephyr.v1.history',
  prefs: 'zephyr.v1.prefs',
} as const

export function loadJSON<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    if (raw == null) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function saveJSON(key: string, value: unknown): void {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Quota exceeded or unavailable — reading must never break.
  }
}
