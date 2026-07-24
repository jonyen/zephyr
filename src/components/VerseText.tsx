import { Fragment } from 'react'
import type { Verse, Highlight } from '../lib/types'
import { bionicWords } from '../lib/bionic'

interface Props { verse: Verse; isRed: boolean; highlights: Highlight[]; bionic: boolean }

/** Split verse text into segments at highlight boundaries. */
function segments(text: string, hls: Highlight[]): Array<{ text: string; color?: string }> {
  if (!hls.length) return [{ text }]
  const bounds = new Set([0, text.length])
  for (const h of hls) { bounds.add(Math.max(0, h.startChar)); bounds.add(Math.min(text.length, h.endChar)) }
  const cuts = [...bounds].sort((a, b) => a - b)
  const out: Array<{ text: string; color?: string }> = []
  for (let i = 0; i < cuts.length - 1; i++) {
    const [s, e] = [cuts[i], cuts[i + 1]]
    const hl = hls.find((h) => h.startChar <= s && h.endChar >= e)
    out.push({ text: text.slice(s, e), color: hl?.color })
  }
  return out
}

function renderText(text: string, bionic: boolean) {
  if (!bionic) return text
  return bionicWords(text).map((w, i) => (
    <Fragment key={i}><b>{w.bold}</b>{w.rest}</Fragment>
  ))
}

export default function VerseText({ verse, isRed, highlights, bionic }: Props) {
  return (
    <span className={isRed ? 'verse red-letter' : 'verse'} data-verse={verse.number}>
      <sup className="verse-num">{verse.number}</sup>
      {segments(verse.text, highlights).map((seg, i) =>
        seg.color
          ? <mark key={i} className={`hl hl-${seg.color}`}>{renderText(seg.text, bionic)}</mark>
          : <Fragment key={i}>{renderText(seg.text, bionic)}</Fragment>,
      )}
    </span>
  )
}
