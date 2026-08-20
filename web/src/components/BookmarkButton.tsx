import { useNav } from './Reader'
import { useAnnotations } from '../state/annotations'
import { BookmarkIcon } from './Icons'

export default function BookmarkButton() {
  const { position } = useNav()
  const { bookmarks, toggleBookmark } = useAnnotations()
  const active = bookmarks.some((b) => b.book === position.book && b.chapter === position.chapter)
  return (
    <button
      className={active ? 'corner-btn active' : 'corner-btn'}
      title="Bookmark (⌘D)"
      aria-label={active ? 'Remove bookmark' : 'Bookmark this chapter'}
      aria-pressed={active}
      onClick={() => toggleBookmark(position.book, position.chapter)}
    >
      <BookmarkIcon filled={active} />
    </button>
  )
}
