import { useMemo, useState } from 'react'
import { BOOKS, TOTAL_CHAPTERS } from '../lib/bible-index'
import { spaceLabels } from '../lib/label-spacing'
import { STRIP_WIDTH, TRACK_INSET } from './Scrubber'

export const PANEL_WIDTH = 180

interface Props {
  trackHeight: number
  currentFraction: number
  focusedBookIndex: number       // current book, or wheel-preview override
  onHoverChange: (hovering: boolean) => void
  onSelectBook: (bookName: string) => void
  onWheel: (e: React.WheelEvent) => void
}

export default function ScrubberPanel({ trackHeight, currentFraction, focusedBookIndex, onHoverChange, onSelectBook, onWheel }: Props) {
  const [hoveredRow, setHoveredRow] = useState<number | null>(null)

  const fractions = useMemo(() => {
    const mids = BOOKS.map((b) => (b.start + b.chapters / 2) / TOTAL_CHAPTERS)
    return spaceLabels(mids, trackHeight, 20)
  }, [trackHeight])

  // Translate the whole label stack so the focused book's label aligns with the thumb.
  const thumbY = TRACK_INSET + currentFraction * trackHeight
  const focusedLabelY = TRACK_INSET + fractions[focusedBookIndex] * trackHeight
  const delta = thumbY - focusedLabelY

  const firstY = TRACK_INSET + fractions[0] * trackHeight + delta
  const lastY = TRACK_INSET + fractions[fractions.length - 1] * trackHeight + delta

  return (
    <div
      className="scrubber-panel"
      style={{ right: STRIP_WIDTH + 4, width: PANEL_WIDTH }}
      onPointerEnter={() => onHoverChange(true)}
      onPointerLeave={() => { onHoverChange(false); setHoveredRow(null) }}
      onWheel={onWheel}
    >
      <div className="scrubber-panel-bg" style={{ top: firstY - 12, height: lastY - firstY + 24 }} />
      {BOOKS.map((b, i) => {
        const y = TRACK_INSET + fractions[i] * trackHeight + delta
        const isCurrent = i === focusedBookIndex
        const isHovered = i === hoveredRow
        const distance = Math.abs(i - focusedBookIndex)
        const opacity = isCurrent || isHovered ? 1 : Math.max(0.3, 1 - distance * 0.07)
        return (
          <button
            key={b.name}
            className={`scrubber-label${isCurrent ? ' current' : ''}${isHovered ? ' hovered' : ''}`}
            style={{ top: y - 11, opacity }}
            onPointerEnter={() => setHoveredRow(i)}
            onClick={() => onSelectBook(b.name)}
          >
            {b.name}
          </button>
        )
      })}
    </div>
  )
}
