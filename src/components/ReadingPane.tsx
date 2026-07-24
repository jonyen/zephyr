import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { Book, Position } from '../lib/types'
import { chapterAfter, chapterBefore, globalIndex } from '../lib/bible-nav'
import { loadBook, loadRedLetter, type RedLetterMap } from '../lib/bible-data'
import ChapterView from './ChapterView'
import { useAnnotations } from '../state/annotations'

const MAX_CHAPTERS = 12

interface Props {
  target: Position
  navId: number                 // increments on every explicit navigation
  targetVerseRange?: { start: number; end: number } | null
  onPositionChange: (pos: Position) => void
}

export default function ReadingPane({ target, navId, targetVerseRange, onPositionChange }: Props) {
  const [chapters, setChapters] = useState<Position[]>([target])
  const [books, setBooks] = useState<Map<string, Book>>(new Map())
  const [redMap, setRedMap] = useState<RedLetterMap>({})
  const [loadError, setLoadError] = useState(false)
  const scrollerRef = useRef<HTMLDivElement>(null)
  const heightBeforeRef = useRef<number | null>(null)   // set before a prepend/trim-from-front
  const reportedRef = useRef<string>('')
  const { highlights, bookmarks } = useAnnotations()

  // Load red letter map once.
  useEffect(() => { loadRedLetter().then(setRedMap).catch(() => {}) }, [])

  // Ensure every listed chapter's book is loaded.
  useEffect(() => {
    const missing = [...new Set(chapters.map((c) => c.book))].filter((b) => !books.has(b))
    if (!missing.length) return
    let cancelled = false
    Promise.all(missing.map((name) => loadBook(name)))
      .then((loaded) => {
        if (cancelled) return
        setBooks((prev) => { const next = new Map(prev); loaded.forEach((b) => next.set(b.name, b)); return next })
        setLoadError(false)
      })
      .catch(() => !cancelled && setLoadError(true))
    return () => { cancelled = true }
  }, [chapters, books])

  // Reset on explicit navigation.
  useEffect(() => {
    setChapters([target])
    heightBeforeRef.current = null
    const el = scrollerRef.current
    if (el) el.scrollTop = 0
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navId])

  // Scroll-anchor compensation: runs synchronously after prepend/front-trim renders.
  useLayoutEffect(() => {
    const el = scrollerRef.current
    if (el && heightBeforeRef.current != null) {
      el.scrollTop += el.scrollHeight - heightBeforeRef.current
      heightBeforeRef.current = null
    }
  }, [chapters])

  // Scroll handling: sentinel-free edge detection + topmost-chapter tracking.
  useEffect(() => {
    const el = scrollerRef.current
    if (!el) return
    let raf = 0
    const onScroll = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const nearTop = el.scrollTop < 600
        const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 600
        if (nearTop) {
          setChapters((cur) => {
            const prev = chapterBefore(cur[0])
            if (!prev || cur.some((c) => globalIndex(c) === globalIndex(prev))) return cur
            heightBeforeRef.current = el.scrollHeight
            const next = [prev, ...cur]
            return next.length > MAX_CHAPTERS ? next.slice(0, MAX_CHAPTERS) : next
          })
        } else if (nearBottom) {
          setChapters((cur) => {
            const nxt = chapterAfter(cur[cur.length - 1])
            if (!nxt || cur.some((c) => globalIndex(c) === globalIndex(nxt))) return cur
            let next = [...cur, nxt]
            if (next.length > MAX_CHAPTERS) {
              heightBeforeRef.current = el.scrollHeight   // trimming from the front shifts content up
              next = next.slice(next.length - MAX_CHAPTERS)
            }
            return next
          })
        }
        // Topmost visible chapter → position report.
        const secs = el.querySelectorAll<HTMLElement>('.chapter')
        let current: HTMLElement | null = null
        for (const s of secs) {
          if (s.offsetTop <= el.scrollTop + 80) current = s
          else break
        }
        const pick = current ?? secs[0]
        if (pick) {
          const key = `${pick.dataset.book}|${pick.dataset.chapter}`
          if (key !== reportedRef.current) {
            reportedRef.current = key
            onPositionChange({ book: pick.dataset.book!, chapter: Number(pick.dataset.chapter) })
          }
        }
      })
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => { el.removeEventListener('scroll', onScroll); cancelAnimationFrame(raf) }
  }, [onPositionChange, navId])

  // Scroll the target verse into view after a search navigation.
  useEffect(() => {
    if (!targetVerseRange) return
    const el = scrollerRef.current
    const t = setTimeout(() => {
      const v = el?.querySelector(`[data-book="${target.book}"][data-chapter="${target.chapter}"] [data-verse="${targetVerseRange.start}"]`)
      v?.scrollIntoView({ block: 'center' })
    }, 60)
    return () => clearTimeout(t)
  }, [navId, targetVerseRange, target])

  return (
    <div className="reading-pane" ref={scrollerRef}>
      {loadError && (
        <div className="load-error">
          Couldn&apos;t load Scripture text. <button onClick={() => setBooks(new Map(books))}>Retry</button>
        </div>
      )}
      {chapters.map((pos) => {
        const book = books.get(pos.book)
        const ch = book?.chapters.find((c) => c.number === pos.chapter)
        if (!book || !ch) return <div key={`${pos.book}-${pos.chapter}`} className="chapter-placeholder" data-book={pos.book} data-chapter={pos.chapter} />
        const isTargetCh = pos.book === target.book && pos.chapter === target.chapter
        return (
          <ChapterView
            key={`${pos.book}-${pos.chapter}`}
            bookName={pos.book}
            chapter={ch}
            showBookTitle={pos.chapter === 1}
            redVerses={redMap[pos.book]?.[String(pos.chapter)] ?? []}
            highlights={highlights.filter((h) => h.book === pos.book && h.chapter === pos.chapter)}
            bookmarked={bookmarks.some((b) => b.book === pos.book && b.chapter === pos.chapter)}
            targetVerseRange={isTargetCh ? targetVerseRange : null}
          />
        )
      })}
    </div>
  )
}
