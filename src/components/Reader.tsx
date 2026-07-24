import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { Navigate, useLocation, useNavigate, useParams } from 'react-router-dom'
import type { Position } from '../lib/types'
import { bookBySlug, slugForPosition } from '../lib/bible-nav'
import ReadingPane from './ReadingPane'
import Scrubber from './Scrubber'
import { useAnnotations } from '../state/annotations'

export interface VerseRange { start: number; end: number }
interface NavCtx { position: Position; jump: (pos: Position, verseRange?: VerseRange, opts?: { replace?: boolean }) => void }
const Ctx = createContext<NavCtx | null>(null)
export function useNav(): NavCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useNav outside Reader')
  return ctx
}

export default function Reader({ children }: { children?: React.ReactNode }) {
  const { slug, chapter } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const { logHistory } = useAnnotations()

  const info = bookBySlug(slug ?? 'genesis')
  const chNum = Number(chapter ?? 1)
  const valid = info && Number.isInteger(chNum) && chNum >= 1 && chNum <= (info?.chapters ?? 0)
  // Stable identity across re-renders (e.g. scroll-driven position updates) so ReadingPane's
  // effects that depend on `target` don't refire when only unrelated state changes.
  const target: Position = useMemo(
    () => (valid ? { book: info!.name, chapter: chNum } : { book: 'Genesis', chapter: 1 }),
    [valid, info?.name, chNum],
  )

  // location.key changes on every push AND back/forward — perfect navId. Skip the initial
  // mount key though: incrementing navId there re-fires ReadingPane's reset effect AFTER its
  // fill effects have already started growing the chapter list, and that mid-flight reset
  // (scrollTop = 0, chaptersRef rewound) races the anchor-compensation captures against a
  // DOM that hasn't committed yet — the cold-navigation position-drift bug.
  const [navId, setNavId] = useState(0)
  const firstKeyRef = useRef(true)
  useEffect(() => {
    if (firstKeyRef.current) { firstKeyRef.current = false; return }
    setNavId((n) => n + 1)
  }, [location.key])

  const [position, setPosition] = useState<Position>(target)
  const historyTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => () => { if (historyTimer.current) clearTimeout(historyTimer.current) }, [])

  const onPositionChange = useCallback((pos: Position) => {
    setPosition(pos)
    // Silent URL update — bypasses the router so ReadingPane doesn't remount.
    const url = `${import.meta.env.BASE_URL}${slugForPosition(pos)}/${pos.chapter}`
    window.history.replaceState(window.history.state, '', url)
    if (historyTimer.current) clearTimeout(historyTimer.current)
    historyTimer.current = setTimeout(() => logHistory(pos.book, pos.chapter), 2000)
  }, [logHistory])

  const jump = useCallback((pos: Position, verseRange?: VerseRange, opts?: { replace?: boolean }) => {
    navigate(`/${slugForPosition(pos)}/${pos.chapter}`, { state: verseRange ? { verseRange } : undefined, replace: opts?.replace ?? false })
  }, [navigate])

  if (!valid && slug) return <Navigate to="/genesis/1" replace />
  const verseRange = (location.state as { verseRange?: VerseRange } | null)?.verseRange ?? null

  return (
    <Ctx.Provider value={{ position, jump }}>
      <ReadingPane target={target} navId={navId} targetVerseRange={verseRange} onPositionChange={onPositionChange} />
      <Scrubber />
      {children}
    </Ctx.Provider>
  )
}
