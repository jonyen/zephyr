import { useAnnotations } from '../state/annotations'
import { useNav } from './Reader'

export default function HistoryOverlay({ onClose }: { onClose: () => void }) {
  const { history } = useAnnotations()
  const { jump } = useNav()
  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box" onClick={(e) => e.stopPropagation()}>
        {history.length === 0 && <div className="search-status">No reading history yet</div>}
        <ul className="history-list">
          {history.map((h, i) => (
            <li key={i} onClick={() => { jump({ book: h.book, chapter: h.chapter }); onClose() }}>
              <span>{h.book} {h.chapter}</span>
              <span className="history-date">{new Date(h.timestamp).toLocaleDateString()}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}
