import { useEffect, useState } from 'react'
import { useAnnotations } from '../state/annotations'
import type { HighlightColor } from '../lib/types'
import { offsetInVerse, verseTextLength } from '../lib/verse-offsets'

const COLORS: HighlightColor[] = ['yellow', 'green', 'blue', 'pink', 'purple']

interface Target { book: string; chapter: number; ranges: Array<{ verse: number; startChar: number; endChar: number }>; x: number; y: number }

const elementOf = (n: Node): Element | null => n.nodeType === Node.ELEMENT_NODE ? (n as Element) : n.parentElement

function computeTarget(): Target | null {
  const sel = window.getSelection()
  if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null
  const range = sel.getRangeAt(0)
  const startVerse = elementOf(range.startContainer)?.closest('.verse')
  const endVerse = elementOf(range.endContainer)?.closest('.verse')
  if (!startVerse || !endVerse) return null
  const chapterEl = startVerse.closest<HTMLElement>('.chapter')
  if (!chapterEl || endVerse.closest('.chapter') !== chapterEl) return null

  const verses = [...chapterEl.querySelectorAll<HTMLElement>('.verse')]
  const si = verses.indexOf(startVerse as HTMLElement), ei = verses.indexOf(endVerse as HTMLElement)
  if (si < 0 || ei < 0) return null
  const ranges = [] as Target['ranges']
  for (let i = si; i <= ei; i++) {
    const v = verses[i]
    const verse = Number(v.dataset.verse)
    const textLen = verseTextLength(v)
    const startChar = i === si ? offsetInVerse(v, range.startContainer, range.startOffset, 0) : 0
    const endChar = i === ei ? offsetInVerse(v, range.endContainer, range.endOffset, textLen) : textLen
    if (endChar > startChar) ranges.push({ verse, startChar, endChar })
  }
  if (!ranges.length) return null
  const rect = range.getBoundingClientRect()
  return { book: chapterEl.dataset.book!, chapter: Number(chapterEl.dataset.chapter), ranges, x: rect.left + rect.width / 2, y: rect.top }
}

export default function SelectionToolbar() {
  const { addHighlight, removeHighlights } = useAnnotations()
  const [target, setTarget] = useState<Target | null>(null)

  useEffect(() => {
    const onUp = () => setTimeout(() => setTarget(computeTarget()), 10)
    const onDown = (e: MouseEvent) => { if (!(e.target as Element).closest('.selection-toolbar')) setTarget(null) }
    document.addEventListener('mouseup', onUp)
    document.addEventListener('mousedown', onDown)
    return () => { document.removeEventListener('mouseup', onUp); document.removeEventListener('mousedown', onDown) }
  }, [])

  if (!target) return null
  const apply = (color: HighlightColor) => {
    for (const r of target.ranges) addHighlight({ book: target.book, chapter: target.chapter, ...r, color })
    window.getSelection()?.removeAllRanges()
    setTarget(null)
  }
  const remove = () => {
    for (const r of target.ranges) removeHighlights(target.book, target.chapter, r.verse, r.startChar, r.endChar)
    window.getSelection()?.removeAllRanges()
    setTarget(null)
  }
  return (
    <div className="selection-toolbar" style={{ left: Math.min(window.innerWidth - 110, Math.max(110, target.x)), top: Math.max(8, target.y - 44) }}>
      {COLORS.map((c) => <button key={c} className={`dot dot-${c}`} onClick={() => apply(c)} title={`Highlight ${c}`} />)}
      <button className="dot dot-remove" onClick={remove} title="Remove highlight">✕</button>
    </div>
  )
}
