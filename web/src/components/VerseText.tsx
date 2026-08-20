import { Fragment } from 'react'
import type { Highlight } from '../lib/types'
import type { VerseLayout, VerseLine } from '../lib/poetry'
import { verseSegments } from '../lib/verse-segments'

interface Props { verse: VerseLayout; isRed: boolean; highlights: Highlight[]; bionic: boolean }

/**
 * Highlights are stored as offsets into the whole verse, so rebase them onto
 * the line's slice before segmenting it. verseSegments clamps the ends, and a
 * range that misses the line entirely lands outside every cut.
 */
function lineContent(line: VerseLine, highlights: Highlight[], bionic: boolean) {
  const local = line.offset === 0
    ? highlights
    : highlights.map((h) => ({ ...h, startChar: h.startChar - line.offset, endChar: h.endChar - line.offset }))
  return verseSegments(line.text, local, bionic).map((seg, i) => {
    const content = seg.bold ? <b>{seg.text}</b> : seg.text
    return seg.color
      ? <mark key={i} className={`hl hl-${seg.color}`}>{content}</mark>
      : <Fragment key={i}>{content}</Fragment>
  })
}

export default function VerseText({ verse, isRed, highlights, bionic }: Props) {
  const num = <sup className="verse-num">{verse.number}</sup>
  return (
    <span
      className={isRed ? 'verse red-letter' : 'verse'}
      data-verse={verse.number}
      data-len={verse.text.length}
    >
      {verse.poetry
        ? verse.lines.map((line, i) => (
            <span key={line.offset} className="poem-line" data-indent={line.indent} data-offset={line.offset}>
              {i === 0 && num}
              {lineContent(line, highlights, bionic)}
            </span>
          ))
        : <>{num}{lineContent(verse.lines[0], highlights, bionic)}</>}
    </span>
  )
}
