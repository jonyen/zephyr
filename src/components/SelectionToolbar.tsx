import { useEffect, useState } from 'react'
import { useAnnotations } from '../state/annotations'
import type { HighlightColor } from '../lib/types'

const COLORS: HighlightColor[] = ['yellow', 'green', 'blue', 'pink', 'purple']

interface Target { book: string; chapter: number; ranges: Array<{ verse: number; startChar: number; endChar: number }>; x: number; y: number }

/** Char offset of `node`+`offset` within a verse span's text content, excluding the verse-number sup. */
function offsetInVerse(verseEl: Element, node: Node, offset: number): number {
  const walker = document.createTreeWalker(verseEl, NodeFilter.SHOW_TEXT)
  let total = 0
  while (walker.nextNode()) {
    const t = walker.currentNode as Text
    if (t.parentElement?.closest('sup.verse-num')) continue
    if (t === node) return total + offset
    total += t.length
  }
  return total
}

function computeTarget(): Target | null {
  const sel = window.getSelection()
  if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null
  const range = sel.getRangeAt(0)
  const startVerse = (range.startContainer.parentElement)?.closest('.verse')
  const endVerse = (range.endContainer.parentElement)?.closest('.verse')
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
    const textLen = [...(function* () { const w = document.createTreeWalker(v, NodeFilter.SHOW_TEXT); while (w.nextNode()) { const t = w.currentNode as Text; if (!t.parentElement?.closest('sup.verse-num')) yield t.length } })()].reduce((a, b) => a + b, 0)
    const startChar = i === si ? offsetInVerse(v, range.startContainer, range.startOffset) : 0
    const endChar = i === ei ? offsetInVerse(v, range.endContainer, range.endOffset) : textLen
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
    <div className="selection-toolbar" style={{ left: target.x, top: Math.max(8, target.y - 44) }}>
      {COLORS.map((c) => <button key={c} className={`dot dot-${c}`} onClick={() => apply(c)} title={`Highlight ${c}`} />)}
      <button className="dot dot-remove" onClick={remove} title="Remove highlight">✕</button>
    </div>
  )
}
