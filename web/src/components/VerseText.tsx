import { Fragment } from 'react'
import type { Verse, Highlight } from '../lib/types'
import { verseSegments } from '../lib/verse-segments'

interface Props { verse: Verse; isRed: boolean; highlights: Highlight[]; bionic: boolean }

export default function VerseText({ verse, isRed, highlights, bionic }: Props) {
  return (
    <span className={isRed ? 'verse red-letter' : 'verse'} data-verse={verse.number}>
      <sup className="verse-num">{verse.number}</sup>
      {verseSegments(verse.text, highlights, bionic).map((seg, i) => {
        const content = seg.bold ? <b>{seg.text}</b> : seg.text
        return seg.color
          ? <mark key={i} className={`hl hl-${seg.color}`}>{content}</mark>
          : <Fragment key={i}>{content}</Fragment>
      })}
    </span>
  )
}
