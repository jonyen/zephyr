import { useNav } from './Reader'
import { useAnnotations } from '../state/annotations'

export default function BookmarkButton() {
  const { position } = useNav()
  const { bookmarks, toggleBookmark } = useAnnotations()
  const active = bookmarks.some((b) => b.book === position.book && b.chapter === position.chapter)
  return <button className="corner-btn" style={{ right: 12 }} title="Bookmark (⌘D)" onClick={() => toggleBookmark(position.book, position.chapter)}>{active ? '⚑' : '⚐'}</button>
}
