import { useMemo } from 'react'
import type { Chapter, Highlight } from '../lib/types'
import { layoutVerses, paragraphs } from '../lib/poetry'
import { usePrefs } from '../state/prefs'
import VerseText from './VerseText'

interface Props {
  bookName: string
  chapter: Chapter
  showBookTitle: boolean
  redVerses: number[]           // verse numbers in this chapter that are red-letter
  paragraphStarts: number[]     // verse numbers that open a paragraph, from the ESV's layout
  highlights: Highlight[]       // highlights for this chapter only
  bookmarked: boolean
  targetVerseRange?: { start: number; end: number } | null  // flash highlight from search nav
}

export default function ChapterView({ bookName, chapter, showBookTitle, redVerses, paragraphStarts, highlights, bookmarked, targetVerseRange }: Props) {
  const { prefs } = usePrefs()
  const redSet = useMemo(() => new Set(prefs.redLetter ? redVerses : []), [prefs.redLetter, redVerses])
  const groups = useMemo(
    () => paragraphs(layoutVerses(chapter.verses), paragraphStarts),
    [chapter.verses, paragraphStarts],
  )
  const inTarget = (n: number) => !!targetVerseRange && n >= targetVerseRange.start && n <= targetVerseRange.end

  return (
    <section className="chapter" data-book={bookName} data-chapter={chapter.number}>
      {showBookTitle && <h1 className="book-title">{bookName}</h1>}
      <div className="chapter-body">
        <span className={groups[0]?.[0]?.poetry ? 'drop-cap drop-cap-poem' : 'drop-cap'}>
          {chapter.number}
          {bookmarked && <span className="bookmark-flag" title="Bookmarked">&#9873;</span>}
        </span>
        {groups.map((verses) => (
          <p className="verses" key={verses[0].number}>
            {verses.map((v, i) => (
              <span key={v.number} className={inTarget(v.number) ? 'verse-target' : undefined}>
                <VerseText verse={v} isRed={redSet.has(v.number)} highlights={highlights.filter((h) => h.verse === v.number)} bionic={prefs.bionic} />
                {/* Poetic verses render as blocks, which break on their own. */}
                {!v.poetry && !verses[i + 1]?.poetry ? ' ' : null}
              </span>
            ))}
          </p>
        ))}
      </div>
      <hr className="chapter-divider" />
    </section>
  )
}
