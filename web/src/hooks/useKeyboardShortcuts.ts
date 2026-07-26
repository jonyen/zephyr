import { useEffect } from 'react'
import { chapterAfter, chapterBefore } from '../lib/bible-nav'
import { useNav } from '../components/Reader'
import { useAnnotations } from '../state/annotations'
import type { OverlayName } from '../App'

export function useKeyboardShortcuts(overlay: OverlayName, setOverlay: (o: OverlayName) => void) {
  const { position, jump } = useNav()
  const { toggleBookmark } = useAnnotations()

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName
      if (e.key === 'Escape') { setOverlay(null); return }
      if (tag === 'INPUT' || tag === 'TEXTAREA' || overlay) return
      const mod = e.metaKey || e.ctrlKey
      if (mod && e.key === 'k') { e.preventDefault(); setOverlay('search') }
      else if (mod && e.key === 'd') { e.preventDefault(); toggleBookmark(position.book, position.chapter) }
      else if (!mod && e.key === '/') { e.preventDefault(); setOverlay('search') }
      else if (!mod && e.key === 't') setOverlay('toc')
      else if (!mod && e.key === 'h') setOverlay('history')
      else if (!mod && e.key === '?') setOverlay('shortcuts')
      else if (e.key === 'ArrowRight') { const n = chapterAfter(position); if (n) jump(n) }
      else if (e.key === 'ArrowLeft') { const p = chapterBefore(position); if (p) jump(p) }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [overlay, setOverlay, position, jump, toggleBookmark])
}
