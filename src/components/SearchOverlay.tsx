import { useEffect, useRef, useState } from 'react'
import { parseReference } from '../lib/reference-parser'
import { searchVerses, type SearchResult } from '../lib/search'
import { loadAllBooks } from '../lib/bible-data'
import { useNav } from './Reader'
import type { Book } from '../lib/types'

export default function SearchOverlay({ onClose }: { onClose: () => void }) {
  const { jump } = useNav()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [selected, setSelected] = useState(0)
  const [loading, setLoading] = useState<string | null>(null)
  const booksRef = useRef<Book[] | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const ref = parseReference(query)

  useEffect(() => { inputRef.current?.focus() }, [])

  useEffect(() => {
    if (ref || query.trim().length < 3) { setResults([]); return }
    let cancelled = false
    const t = setTimeout(async () => {
      if (!booksRef.current) {
        setLoading('Loading Scripture…')
        try {
          booksRef.current = await loadAllBooks((n, total) => setLoading(`Loading Scripture… ${n}/${total}`))
        } catch {
          if (!cancelled) setLoading('Couldn’t load Scripture text — check your connection and try again.')
          return
        }
        setLoading(null)
      }
      if (!cancelled) { setResults(searchVerses(query, booksRef.current)); setSelected(0) }
    }, 250)
    return () => { cancelled = true; clearTimeout(t) }
  }, [query])   // eslint-disable-line react-hooks/exhaustive-deps

  const go = (r?: SearchResult) => {
    if (ref) {
      jump({ book: ref.book, chapter: ref.chapter }, ref.verse ? { start: ref.verse, end: ref.verseEnd ?? ref.verse } : undefined)
    } else if (r) {
      jump({ book: r.book, chapter: r.chapter }, { start: r.verse, end: r.verse })
    } else return
    onClose()
  }

  const shown = results.slice(0, 50)

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose()
    else if (e.key === 'Enter') go(shown[selected])
    else if (e.key === 'ArrowDown') { e.preventDefault(); setSelected((s) => Math.min(shown.length - 1, s + 1)) }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setSelected((s) => Math.max(0, s - 1)) }
  }

  return (
    <div className="overlay-backdrop" onMouseDown={onClose}>
      <div className="search-box" onClick={(e) => e.stopPropagation()} onMouseDown={(e) => e.stopPropagation()} onKeyDown={onKeyDown}>
        <input ref={inputRef} value={query} placeholder="Search — “John 3:16” or keywords" onChange={(e) => setQuery(e.target.value)} />
        {ref && <div className="search-ref-hint">↵ Go to {ref.book} {ref.chapter}{ref.verse ? `:${ref.verse}` : ''}{ref.verseEnd ? `–${ref.verseEnd}` : ''}</div>}
        {loading && <div className="search-status">{loading}</div>}
        {!ref && results.length > 0 && (
          <ul className="search-results">
            {shown.map((r, i) => (
              <li key={`${r.book}${r.chapter}:${r.verse}`} className={i === selected ? 'selected' : ''} onClick={() => go(r)} onMouseEnter={() => setSelected(i)}>
                <span className="result-ref">{r.book} {r.chapter}:{r.verse}</span>
                <span className="result-text">
                  {r.text.slice(Math.max(0, r.matchStart - 30), r.matchStart)}
                  <b>{r.text.slice(r.matchStart, r.matchEnd)}</b>
                  {r.text.slice(r.matchEnd, r.matchEnd + 60)}
                </span>
              </li>
            ))}
          </ul>
        )}
        {!ref && !loading && query.trim().length >= 3 && results.length === 0 && <div className="search-status">No results</div>}
      </div>
    </div>
  )
}
