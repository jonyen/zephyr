import type { OverlayName } from '../App'
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts'
import SearchOverlay from './SearchOverlay'
import TocOverlay from './TocOverlay'
import HistoryOverlay from './HistoryOverlay'
import ShortcutsOverlay from './ShortcutsOverlay'
import SettingsPopover from './SettingsPopover'
import BookmarkButton from './BookmarkButton'

export default function ReaderChrome({ overlay, setOverlay }: { overlay: OverlayName; setOverlay: (o: OverlayName) => void }) {
  useKeyboardShortcuts(overlay, setOverlay)
  return (
    <>
      {overlay === 'search' && <SearchOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'toc' && <TocOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'history' && <HistoryOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'shortcuts' && <ShortcutsOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'settings' && <SettingsPopover onClose={() => setOverlay(null)} />}
      <BookmarkButton />
      <button className="corner-btn" style={{ right: 44 }} title="Search (⌘K)" onClick={() => setOverlay('search')}>&#8981;</button>
      <button className="corner-btn" style={{ right: 76 }} title="Contents (t)" onClick={() => setOverlay('toc')}>☰</button>
      <button className="corner-btn" style={{ right: 108 }} title="History (h)" onClick={() => setOverlay('history')}>🕘</button>
      <button className="corner-btn" style={{ right: 140 }} title="Settings" onClick={() => setOverlay('settings')}>⚙</button>
    </>
  )
}
