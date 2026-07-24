import { useCallback, useEffect, useRef, useState } from 'react'
import { BOOKS, TOTAL_CHAPTERS } from '../lib/bible-index'
import { bookByName, globalIndex, positionForGlobalIndex } from '../lib/bible-nav'
import { useNav } from './Reader'
import { useAnnotations } from '../state/annotations'
import ScrubberPanel from './ScrubberPanel'

export const TRACK_INSET = 20
export const STRIP_WIDTH = 30

export default function Scrubber() {
  const { position, jump } = useNav()
  const { highlights, bookmarks } = useAnnotations()
  const stripRef = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState(0)
  const [hovered, setHovered] = useState(false)
  const [panelHovered, setPanelHovered] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [dragFraction, setDragFraction] = useState(0)
  const [visible, setVisible] = useState(false)
  const [wheelBookIndex, setWheelBookIndex] = useState<number | null>(null)
  const hideTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const lastNavigated = useRef(-1)
  const wheelAccum = useRef(0)

  useEffect(() => {
    const el = stripRef.current
    if (!el) return
    const ro = new ResizeObserver(() => setHeight(el.clientHeight))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Belt-and-suspenders: annotations are sanitized on load, but guard marker rendering too so a
  // stray unknown-book entry (e.g. from a future schema change) can't throw during paint —
  // globalIndex() throws for books it doesn't recognize.
  const fractionForPosition = useCallback((pos: { book: string; chapter: number }): number | null => {
    if (!bookByName(pos.book)) return null
    try {
      return globalIndex(pos) / (TOTAL_CHAPTERS - 1)
    } catch {
      return null
    }
  }, [])

  const trackHeight = Math.max(0, height - TRACK_INSET * 2)
  const currentFraction = dragging ? dragFraction : globalIndex(position) / (TOTAL_CHAPTERS - 1)
  const thumbY = TRACK_INSET + currentFraction * trackHeight

  const fractionForClientY = useCallback((clientY: number) => {
    const rect = stripRef.current!.getBoundingClientRect()
    const y = clientY - rect.top
    return Math.min(1, Math.max(0, (y - TRACK_INSET) / trackHeight))
  }, [trackHeight])

  const navigateToFraction = useCallback((fraction: number) => {
    const idx = Math.round(fraction * (TOTAL_CHAPTERS - 1))
    if (idx !== lastNavigated.current) {
      lastNavigated.current = idx
      jump(positionForGlobalIndex(idx), undefined, { replace: true })
    }
  }, [jump])

  const onPointerDown = (e: React.PointerEvent) => {
    stripRef.current!.setPointerCapture(e.pointerId)
    setDragging(true)
    const f = fractionForClientY(e.clientY)
    setDragFraction(f)
    navigateToFraction(f)
  }
  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragging) return
    const f = fractionForClientY(e.clientY)
    setDragFraction(f)
    navigateToFraction(f)
  }
  const onPointerUp = () => { setDragging(false); lastNavigated.current = -1 }

  const showLabels = hovered || dragging || panelHovered
  useEffect(() => {
    if (showLabels) {
      if (hideTimer.current) clearTimeout(hideTimer.current)
      setVisible(true)
    } else {
      hideTimer.current = setTimeout(() => { setVisible(false); setWheelBookIndex(null); wheelAccum.current = 0 }, 150)
    }
    return () => { if (hideTimer.current) clearTimeout(hideTimer.current) }
  }, [showLabels])

  const currentBookIndex = BOOKS.findIndex((b) => b.name === position.book)
  const focusedBookIndex = wheelBookIndex ?? Math.max(0, currentBookIndex)

  const onWheel = (e: React.WheelEvent) => {
    if (!showLabels) return
    wheelAccum.current += e.deltaY
    if (Math.abs(wheelAccum.current) < 40) return
    const step = wheelAccum.current > 0 ? 1 : -1
    wheelAccum.current -= 40 * step
    setWheelBookIndex((cur) => Math.max(0, Math.min(BOOKS.length - 1, (cur ?? Math.max(0, currentBookIndex)) + step)))
  }

  const cx = STRIP_WIDTH / 2
  return (
    <div className="scrubber-zone">
      <div
        ref={stripRef}
        className="scrubber-strip"
        data-hovered={hovered}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onPointerEnter={() => setHovered(true)}
        onPointerLeave={() => setHovered(false)}
        onWheel={onWheel}
      >
        <svg width={STRIP_WIDTH} height={height || 1}>
          <rect x={cx - 1} y={TRACK_INSET} width={2} height={trackHeight} rx={1} className="scrubber-track" />
          {highlights.map((h, i) => {
            const f = fractionForPosition({ book: h.book, chapter: h.chapter })
            if (f == null) return null
            const y = TRACK_INSET + f * trackHeight
            return <rect key={`h${i}`} x={cx - 8} y={y - 1.5} width={6} height={3} rx={1} className={`tick-${h.color}`} />
          })}
          {bookmarks.map((b, i) => {
            const f = fractionForPosition(b)
            if (f == null) return null
            const y = TRACK_INSET + f * trackHeight
            return <path key={`b${i}`} d={`M ${cx + 3} ${y - 3} L ${cx + 6} ${y} L ${cx + 3} ${y + 3} L ${cx} ${y} Z`} className="scrubber-bookmark" />
          })}
          <rect x={cx - 3} y={thumbY - 15} width={6} height={30} rx={3} className="scrubber-thumb" />
        </svg>
      </div>
      {visible && (
        <ScrubberPanel
          trackHeight={trackHeight}
          currentFraction={currentFraction}
          focusedBookIndex={focusedBookIndex}
          onHoverChange={setPanelHovered}
          onSelectBook={(name) => { jump({ book: name, chapter: 1 }); setWheelBookIndex(null) }}
          onWheel={onWheel}
        />
      )}
    </div>
  )
}
