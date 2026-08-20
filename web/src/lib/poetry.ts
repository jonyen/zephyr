/**
 * Poetic layout for a chapter.
 *
 * The scripture data encodes poetry inside the verse text itself: a newline
 * starts a new poetic line, and leading spaces (4 per level) set its indent.
 * Nothing marks where a *verse* begins a poetic line, so we infer it — a verse
 * is laid out as poetry when it carries a line break, or when it sits between
 * verses that do.
 *
 * Poetic verses render as block lines, which break away from the surrounding
 * prose on their own; prose verses keep flowing inline as before.
 *
 * Verse text is never modified here. Each line carries the offset of its slice
 * within the original verse text so highlight ranges can be rebased onto it.
 */

const SPACES_PER_INDENT = 4

export interface VerseLine {
  text: string      // one poetic line, leading indent spaces removed
  offset: number    // where `text` begins inside the full verse text
  indent: number    // indent level, 0 = flush left
}

export interface VerseLayout {
  number: number
  text: string
  poetry: boolean   // render as block lines with a hanging indent
  lines: VerseLine[]
}

/** A verse is poetry when it carries an internal line break. */
export function isPoetry(text: string): boolean {
  return text.includes('\n')
}

/** Split verse text on newlines, peeling off each line's indent spaces. */
export function verseLines(text: string): VerseLine[] {
  const out: VerseLine[] = []
  let offset = 0
  for (const raw of text.split('\n')) {
    const stripped = raw.replace(/^ +/, '')
    const spaces = raw.length - stripped.length
    out.push({ text: stripped, offset: offset + spaces, indent: Math.floor(spaces / SPACES_PER_INDENT) })
    offset += raw.length + 1 // + the newline we split on
  }
  return out
}

export function layoutVerses(verses: { number: number; text: string }[]): VerseLayout[] {
  // The ESV omits a handful of verses (Mark 9:44, Acts 8:37, …) as later
  // manuscript additions. They carry no text, so they get no line of their own.
  const present = verses.filter((v) => v.text !== '')
  const broken = present.map((v) => isPoetry(v.text))

  return present.map((verse, i) => ({
    number: verse.number,
    text: verse.text,
    // A lone unbroken verse surrounded by broken ones belongs to the poem.
    poetry: broken[i] || ((i === 0 || broken[i - 1]) && broken[i + 1] === true),
    lines: verseLines(verse.text),
  }))
}

/**
 * Group a chapter's verses into paragraphs.
 *
 * `starts` lists the verses that open a paragraph, from the ESV's own layout.
 * A break aimed at a verse the ESV omits carries forward to the next verse
 * present, so the paragraph is not lost with it.
 */
export function paragraphs(verses: VerseLayout[], starts: number[]): VerseLayout[][] {
  if (!verses.length) return []
  const opens = [...starts].sort((a, b) => a - b)
  const groups: VerseLayout[][] = []
  let current: VerseLayout[] = []
  let next = 0

  for (const verse of verses) {
    // Consume every break at or before this verse. One aimed at a verse the
    // ESV omits lands here instead of being dropped with it.
    let breaks = false
    while (next < opens.length && opens[next] <= verse.number) {
      breaks = true
      next++
    }
    if (breaks && current.length) {
      groups.push(current)
      current = []
    }
    current.push(verse)
  }
  if (current.length) groups.push(current)
  return groups
}

/** A section heading the ESV prints above the verse it names. */
export interface Heading { verse: number; text: string }

/**
 * The heading that belongs above this paragraph, if any.
 *
 * A heading sits above a paragraph, never inside one, so it only applies when
 * its verse is the one the paragraph opens with.
 */
export function headingFor(paragraph: VerseLayout[], headings: Heading[]): Heading | undefined {
  const first = paragraph[0]
  if (!first) return undefined
  return headings.find((h) => h.verse === first.number)
}
