import { useMemo } from 'react'
import type { Chapter, Highlight } from '../lib/types'
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
  const oneVersePerLine = bookName === 'Proverbs'
  const inTarget = (n: number) => !!targetVerseRange && n >= targetVerseRange.start && n <= targetVerseRange.end

  return (
    <section className="chapter" data-book={bookName} data-chapter={chapter.number}>
      {showBookTitle && <h1 className="book-title">{bookName}</h1>}
      <div className="chapter-body">
        <span className="drop-cap">
          {chapter.number}
          {bookmarked && <span className="bookmark-flag" title="Bookmarked">&#9873;</span>}
        </span>
        <p className={oneVersePerLine ? 'verses verses-lines' : 'verses'}>
          {chapter.verses.map((v) => (
            <span key={v.number} className={inTarget(v.number) ? 'verse-target' : undefined}>
              <VerseText verse={v} isRed={redSet.has(v.number)} highlights={highlights.filter((h) => h.verse === v.number)} bionic={prefs.bionic} />
              {oneVersePerLine ? null : ' '}
            </span>
          ))}
        </p>
      </div>
      <hr className="chapter-divider" />
    </section>
  )
}
