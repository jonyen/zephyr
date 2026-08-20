import { Fragment, useMemo } from 'react'
import type { Chapter, Highlight } from '../lib/types'
import { headingFor, layoutVerses, paragraphs, type Heading } from '../lib/poetry'
import { usePrefs } from '../state/prefs'
import VerseText from './VerseText'

interface Props {
  bookName: string
  chapter: Chapter
  showBookTitle: boolean
  redVerses: number[]           // verse numbers in this chapter that are red-letter
  paragraphStarts: number[]     // verse numbers that open a paragraph, from the ESV's layout
  headings: Heading[]           // the ESV's section headings for this chapter
  psalmTitle?: string           // a psalm's superscription, printed above verse 1
  highlights: Highlight[]       // highlights for this chapter only
  bookmarked: boolean
  targetVerseRange?: { start: number; end: number } | null  // flash highlight from search nav
}

export default function ChapterView({ bookName, chapter, showBookTitle, redVerses, paragraphStarts, headings, psalmTitle, highlights, bookmarked, targetVerseRange }: Props) {
  const { prefs } = usePrefs()
  const redSet = useMemo(() => new Set(prefs.redLetter ? redVerses : []), [prefs.redLetter, redVerses])
  const groups = useMemo(
    () => paragraphs(layoutVerses(chapter.verses), paragraphStarts),
    [chapter.verses, paragraphStarts],
  )
  const inTarget = (n: number) => !!targetVerseRange && n >= targetVerseRange.start && n <= targetVerseRange.end
  // The chapter's opening heading goes above the drop cap rather than beside
  // it — the drop cap floats, so a heading inside the body would be pushed
  // right and read as though the chapter number were part of it.
  const leadHeading = groups.length ? headingFor(groups[0], headings) : undefined

  return (
    <section className="chapter" data-book={bookName} data-chapter={chapter.number}>
      {showBookTitle && <h1 className="book-title">{bookName}</h1>}
      {leadHeading && <h2 className="section-heading section-heading-lead">{leadHeading.text}</h2>}
      {psalmTitle && <p className="psalm-title">{psalmTitle}</p>}
      <div className="chapter-body">
        <span className={groups[0]?.[0]?.poetry ? 'drop-cap drop-cap-poem' : 'drop-cap'}>
          {chapter.number}
          {bookmarked && <span className="bookmark-flag" title="Bookmarked">&#9873;</span>}
        </span>
        {groups.map((verses, group) => (
          <Fragment key={verses[0].number}>
            {group > 0 && headingFor(verses, headings) && (
              <h2 className="section-heading">{headingFor(verses, headings)!.text}</h2>
            )}
          <p className="verses">
            {verses.map((v, i) => (
              <span key={v.number} className={inTarget(v.number) ? 'verse-target' : undefined}>
                <VerseText verse={v} isRed={redSet.has(v.number)} highlights={highlights.filter((h) => h.verse === v.number)} bionic={prefs.bionic} />
                {/* Poetic verses render as blocks, which break on their own. */}
                {!v.poetry && !verses[i + 1]?.poetry ? ' ' : null}
              </span>
            ))}
          </p>
          </Fragment>
        ))}
      </div>
      <hr className="chapter-divider" />
    </section>
  )
}
