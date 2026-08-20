import { useMemo } from 'react'
import type { Chapter, Highlight } from '../lib/types'
import { layoutVerses } from '../lib/poetry'
import { usePrefs } from '../state/prefs'
import VerseText from './VerseText'

interface Props {
  bookName: string
  chapter: Chapter
  showBookTitle: boolean
  redVerses: number[]           // verse numbers in this chapter that are red-letter
  highlights: Highlight[]       // highlights for this chapter only
  bookmarked: boolean
  targetVerseRange?: { start: number; end: number } | null  // flash highlight from search nav
}

export default function ChapterView({ bookName, chapter, showBookTitle, redVerses, highlights, bookmarked, targetVerseRange }: Props) {
  const { prefs } = usePrefs()
  const redSet = useMemo(() => new Set(prefs.redLetter ? redVerses : []), [prefs.redLetter, redVerses])
  const verses = useMemo(() => layoutVerses(chapter.verses), [chapter.verses])
  const inTarget = (n: number) => !!targetVerseRange && n >= targetVerseRange.start && n <= targetVerseRange.end

  return (
    <section className="chapter" data-book={bookName} data-chapter={chapter.number}>
      {showBookTitle && <h1 className="book-title">{bookName}</h1>}
      <div className="chapter-body">
        <span className={verses[0]?.poetry ? 'drop-cap drop-cap-poem' : 'drop-cap'}>
          {chapter.number}
          {bookmarked && <span className="bookmark-flag" title="Bookmarked">&#9873;</span>}
        </span>
        <p className="verses">
          {verses.map((v, i) => (
            <span key={v.number} className={inTarget(v.number) ? 'verse-target' : undefined}>
              <VerseText verse={v} isRed={redSet.has(v.number)} highlights={highlights.filter((h) => h.verse === v.number)} bionic={prefs.bionic} />
              {/* Poetic verses render as blocks, which break on their own. */}
              {!v.poetry && !verses[i + 1]?.poetry ? ' ' : null}
            </span>
          ))}
        </p>
      </div>
      <hr className="chapter-divider" />
    </section>
  )
}
