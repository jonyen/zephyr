import { bionicWords } from './bionic'
import type { Highlight } from './types'

export interface VerseSegment { text: string; color?: string; bold?: boolean }

interface BoldRange { start: number; boldEnd: number }

/**
 * Compute [start, boldEnd) ranges for each word's bionic-bold prefix, in original
 * text offsets. Bold length is computed against the FULL word (via bionicWords),
 * so a highlight boundary that lands mid-word does not skew the bold ratio.
 */
function boldRanges(text: string): BoldRange[] {
  const out: BoldRange[] = []
  let offset = 0
  for (const { bold, rest } of bionicWords(text)) {
    if (bold) out.push({ start: offset, boldEnd: offset + bold.length })
    offset += bold.length + rest.length
  }
  return out
}

export function verseSegments(text: string, highlights: Highlight[], bionic: boolean): VerseSegment[] {
  if (!text) return [{ text: '' }]

  const bounds = new Set<number>([0, text.length])
  for (const h of highlights) {
    bounds.add(Math.max(0, Math.min(text.length, h.startChar)))
    bounds.add(Math.max(0, Math.min(text.length, h.endChar)))
  }
  const words = bionic ? boldRanges(text) : []
  for (const w of words) { bounds.add(w.start); bounds.add(w.boldEnd) }

  const cuts = [...bounds].sort((a, b) => a - b)
  const out: VerseSegment[] = []
  for (let i = 0; i < cuts.length - 1; i++) {
    const s = cuts[i]
    const e = cuts[i + 1]
    if (s >= e) continue

    // Last highlight in the array covering the whole segment wins.
    let color: string | undefined
    for (const h of highlights) {
      if (h.startChar <= s && h.endChar >= e) color = h.color
    }
    const bold = words.some((w) => w.start <= s && w.boldEnd >= e)

    const seg: VerseSegment = { text: text.slice(s, e) }
    if (color) seg.color = color
    if (bold) seg.bold = true
    out.push(seg)
  }
  return out
}
