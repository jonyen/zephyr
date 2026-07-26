import { useState } from 'react'
import { BOOKS, type BookInfo } from '../lib/bible-index'
import { useNav } from './Reader'

export default function TocOverlay({ onClose }: { onClose: () => void }) {
  const { position, jump } = useNav()
  const [book, setBook] = useState<BookInfo | null>(null)

  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box" onClick={(e) => e.stopPropagation()}>
        {!book ? (
          <div className="toc-grid">
            {BOOKS.map((b) => (
              <button key={b.name} className={b.name === position.book ? 'toc-item current' : 'toc-item'} onClick={() => setBook(b)}>{b.name}</button>
            ))}
          </div>
        ) : (
          <>
            <button className="toc-back" onClick={() => setBook(null)}>‹ {book.name}</button>
            <div className="toc-grid toc-chapters">
              {Array.from({ length: book.chapters }, (_, i) => i + 1).map((n) => (
                <button key={n} className="toc-item" onClick={() => { jump({ book: book.name, chapter: n }); onClose() }}>{n}</button>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  )
}
