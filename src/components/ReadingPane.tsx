import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
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
  const chaptersRef = useRef<Position[]>([target])        // mirrors `chapters` for synchronous reads in the scroll handler
  const pendingAnchorRef = useRef<{ pos: Position; top: number } | null>(null)   // anchor chapter + its viewport top, set before a chapters mutation
  const reportedRef = useRef<string>('')
  const scrolledForNavRef = useRef<number>(-1)             // navId already handled by the verse-scroll effect
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
    chaptersRef.current = [target]
    setChapters([target])
    pendingAnchorRef.current = null
    const el = scrollerRef.current
    if (el) el.scrollTop = 0
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navId])

  // Scroll-anchor compensation: runs synchronously after an add/trim renders.
  // Re-locates the anchor chapter (one that survived the mutation) and shifts scrollTop by
  // exactly how far its top moved — correct for any combination of prepend/append/trim.
  useLayoutEffect(() => {
    const el = scrollerRef.current
    const pending = pendingAnchorRef.current
    if (el && pending) {
      const a = el.querySelector<HTMLElement>(`[data-book="${pending.pos.book}"][data-chapter="${pending.pos.chapter}"]`)
      if (a) el.scrollTop += a.getBoundingClientRect().top - pending.top
    }
    pendingAnchorRef.current = null
  }, [chapters])

  // Evaluate BOTH scroll edges in one pass (not else-if) and grow `chapters` as needed.
  // Both edges must be checked independently: `else if` made the append branch unreachable
  // whenever nearTop was already true (e.g. short chapters where max scrollTop < 600), and
  // content shorter than the viewport never produces a scroll event at all, so this must
  // also be callable outside the scroll handler (see the fill effect below).
  const ensureEdges = useCallback(() => {
    const el = scrollerRef.current
    if (!el) return
    const cur = chaptersRef.current
    const wantPrepend = el.scrollTop < 600
    const wantAppend = el.scrollHeight - el.scrollTop - el.clientHeight < 600 || el.scrollHeight <= el.clientHeight
    if (!wantPrepend && !wantAppend) return

    const merged = [...cur]
    let didPrepend = false
    let didAppend = false
    if (wantPrepend) {
      const prev = chapterBefore(merged[0])
      if (prev && !merged.some((c) => globalIndex(c) === globalIndex(prev))) {
        merged.unshift(prev)
        didPrepend = true
      }
    }
    if (wantAppend) {
      const nxt = chapterAfter(merged[merged.length - 1])
      if (nxt && !merged.some((c) => globalIndex(c) === globalIndex(nxt))) {
        merged.push(nxt)
        didAppend = true
      }
    }
    if (!didPrepend && !didAppend) return

    let next = merged
    if (next.length > MAX_CHAPTERS) {
      if (didAppend && didPrepend) {
        // Both edges grew this tick — skip trimming; the next tick (scroll or fill-effect
        // rerun) rebalances once it's clear which side is actually away from the viewport.
      } else if (didAppend) {
        next = next.slice(next.length - MAX_CHAPTERS)   // trim the front, away from the viewport
      } else {
        next = next.slice(0, MAX_CHAPTERS)                // trim the end, away from the viewport
      }
    }

    // Anchor on a chapter that survives the mutation (present in both `cur` and `next`);
    // its pre-mutation viewport top lets the layout effect restore scroll position exactly.
    const anchorPos = next.find((p) => cur.some((c) => c.book === p.book && c.chapter === p.chapter)) ?? null
    if (anchorPos) {
      const a = el.querySelector<HTMLElement>(`[data-book="${anchorPos.book}"][data-chapter="${anchorPos.chapter}"]`)
      pendingAnchorRef.current = a ? { pos: anchorPos, top: a.getBoundingClientRect().top } : null
    } else {
      pendingAnchorRef.current = null
    }
    chaptersRef.current = next
    setChapters(next)
  }, [])

  // Topmost visible chapter → position report. Shared by the scroll handler and the fill
  // effect so the URL is correct even when chapters were auto-filled without a user scroll.
  const reportPosition = useCallback(() => {
    const el = scrollerRef.current
    if (!el) return
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
  }, [onPositionChange])

  // Scroll handling: sentinel-free edge detection + topmost-chapter tracking.
  useEffect(() => {
    const el = scrollerRef.current
    if (!el) return
    let raf = 0
    const onScroll = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        ensureEdges()
        reportPosition()
      })
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => { el.removeEventListener('scroll', onScroll); cancelAnimationFrame(raf) }
  }, [ensureEdges, reportPosition, navId])

  // Auto-fill: re-evaluate both edges whenever the rendered content changes (a chapter
  // finished loading, or the DOM grew/shrank). This is what makes short chapters — or a
  // pane where the initial content doesn't even fill the viewport, so no scroll event ever
  // fires — keep loading until there's enough content to scroll at all. `ensureEdges` is a
  // no-op once both edges have enough buffer or MAX_CHAPTERS is reached, so this terminates.
  useEffect(() => {
    ensureEdges()
    reportPosition()
  }, [chapters, books, ensureEdges, reportPosition])

  // Scroll the target verse into view after a search navigation. Guarded so it fires at most
  // once per navId (doesn't refight a user's own scroll), and re-fires as `books` loads so a
  // cold-loaded target chapter is still caught once its verses exist in the DOM.
  useEffect(() => {
    if (!targetVerseRange || scrolledForNavRef.current === navId) return
    const raf = requestAnimationFrame(() => {
      const el = scrollerRef.current
      const v = el?.querySelector(`[data-book="${target.book}"][data-chapter="${target.chapter}"] [data-verse="${targetVerseRange.start}"]`)
      if (v) {
        v.scrollIntoView({ block: 'center' })
        scrolledForNavRef.current = navId
      }
    })
    return () => cancelAnimationFrame(raf)
  }, [navId, targetVerseRange, books, target])

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
