import { useCallback, useEffect, useRef, useState } from 'react'
import { TOTAL_CHAPTERS } from '../lib/bible-index'
import { globalIndex, positionForGlobalIndex } from '../lib/bible-nav'
import { useNav } from './Reader'
import { useAnnotations } from '../state/annotations'

export const TRACK_INSET = 20
export const STRIP_WIDTH = 30

export default function Scrubber() {
  const { position, jump } = useNav()
  const { highlights, bookmarks } = useAnnotations()
  const stripRef = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState(0)
  const [hovered, setHovered] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [dragFraction, setDragFraction] = useState(0)
  const lastNavigated = useRef(-1)

  useEffect(() => {
    const el = stripRef.current
    if (!el) return
    const ro = new ResizeObserver(() => setHeight(el.clientHeight))
    ro.observe(el)
    return () => ro.disconnect()
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
      jump(positionForGlobalIndex(idx))
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

  const cx = STRIP_WIDTH / 2
  return (
    <div
      ref={stripRef}
      className="scrubber-strip"
      data-hovered={hovered}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerEnter={() => setHovered(true)}
      onPointerLeave={() => setHovered(false)}
    >
      <svg width={STRIP_WIDTH} height={height || 1}>
        <rect x={cx - 1} y={TRACK_INSET} width={2} height={trackHeight} rx={1} className="scrubber-track" />
        {highlights.map((h, i) => {
          const y = TRACK_INSET + (globalIndex({ book: h.book, chapter: h.chapter }) / (TOTAL_CHAPTERS - 1)) * trackHeight
          return <rect key={`h${i}`} x={cx - 8} y={y - 1.5} width={6} height={3} rx={1} className={`tick-${h.color}`} />
        })}
        {bookmarks.map((b, i) => {
          const y = TRACK_INSET + (globalIndex(b) / (TOTAL_CHAPTERS - 1)) * trackHeight
          return <path key={`b${i}`} d={`M ${cx + 3} ${y - 3} L ${cx + 6} ${y} L ${cx + 3} ${y + 3} L ${cx} ${y} Z`} className="scrubber-bookmark" />
        })}
        <rect x={cx - 3} y={thumbY - 15} width={6} height={30} rx={3} className="scrubber-thumb" />
      </svg>
    </div>
  )
}
