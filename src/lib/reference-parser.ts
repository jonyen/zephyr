import { BOOKS } from './bible-index'
import { bookByName } from './bible-nav'

export interface ParsedReference { book: string; chapter: number; verse?: number; verseEnd?: number }

// Normalized alias → canonical display name. Full names and slugs are added automatically below.
const ALIASES: Record<string, string> = {
  gen: 'Genesis', ex: 'Exodus', exod: 'Exodus', lev: 'Leviticus', num: 'Numbers',
  deut: 'Deuteronomy', dt: 'Deuteronomy', josh: 'Joshua', judg: 'Judges', jdg: 'Judges',
  ru: 'Ruth', '1 sam': '1 Samuel', '2 sam': '2 Samuel', '1 kgs': '1 Kings', '2 kgs': '2 Kings',
  '1 chr': '1 Chronicles', '2 chr': '2 Chronicles', neh: 'Nehemiah', est: 'Esther',
  ps: 'Psalms', psa: 'Psalms', psalm: 'Psalms', prov: 'Proverbs', pr: 'Proverbs',
  eccl: 'Ecclesiastes', ecc: 'Ecclesiastes', song: 'Song of Solomon', sos: 'Song of Solomon',
  isa: 'Isaiah', jer: 'Jeremiah', lam: 'Lamentations', ezek: 'Ezekiel', dan: 'Daniel',
  hos: 'Hosea', ob: 'Obadiah', obad: 'Obadiah', jon: 'Jonah', mic: 'Micah', nah: 'Nahum',
  hab: 'Habakkuk', zeph: 'Zephaniah', hag: 'Haggai', zech: 'Zechariah', mal: 'Malachi',
  mt: 'Matthew', matt: 'Matthew', mk: 'Mark', lk: 'Luke', jn: 'John', rom: 'Romans',
  '1 cor': '1 Corinthians', '2 cor': '2 Corinthians', gal: 'Galatians', eph: 'Ephesians',
  phil: 'Philippians', col: 'Colossians', '1 thess': '1 Thessalonians', '2 thess': '2 Thessalonians',
  '1 tim': '1 Timothy', '2 tim': '2 Timothy', tit: 'Titus', phlm: 'Philemon', heb: 'Hebrews',
  jas: 'James', '1 pet': '1 Peter', '2 pet': '2 Peter', '1 jn': '1 John', '2 jn': '2 John',
  '3 jn': '3 John', rev: 'Revelation',
}

const lookup = new Map<string, string>()
for (const b of BOOKS) {
  lookup.set(b.name.toLowerCase(), b.name)
  lookup.set(b.slug.replace(/-/g, ' '), b.name)
}
for (const [alias, name] of Object.entries(ALIASES)) {
  // Alias targets use common names; map "Psalms" → whatever the data calls it.
  const resolved = bookByName(name) ?? BOOKS.find((b) => name.toLowerCase().startsWith(b.name.toLowerCase()))
  if (resolved) lookup.set(alias, resolved.name)
}

function normalize(input: string): string {
  return input
    .toLowerCase()
    .replace(/\./g, '')
    .replace(/^iii\s+/, '3 ').replace(/^ii\s+/, '2 ').replace(/^i\s+/, '1 ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function parseReference(input: string): ParsedReference | null {
  const norm = normalize(input)
  if (!norm) return null
  const m = norm.match(/^(\d?\s?[a-z ]+?)(?:\s+(\d+)(?::(\d+)(?:\s*[-–]\s*(\d+))?)?)?$/)
  if (!m) return null
  const bookName = lookup.get(m[1].trim())
  if (!bookName) return null
  const info = bookByName(bookName)!
  const chapter = m[2] ? Math.max(1, Math.min(info.chapters, parseInt(m[2], 10))) : 1
  const ref: ParsedReference = { book: bookName, chapter }
  if (m[3]) ref.verse = parseInt(m[3], 10)
  if (m[4]) ref.verseEnd = parseInt(m[4], 10)
  return ref
}
