import type { OverlayName } from '../App'
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts'
import SearchOverlay from './SearchOverlay'
import TocOverlay from './TocOverlay'
import HistoryOverlay from './HistoryOverlay'
import ShortcutsOverlay from './ShortcutsOverlay'
import SettingsPopover from './SettingsPopover'
import BookmarkButton from './BookmarkButton'
import { ContentsIcon, HistoryIcon, SearchIcon, SettingsIcon } from './Icons'

export default function ReaderChrome({ overlay, setOverlay }: { overlay: OverlayName; setOverlay: (o: OverlayName) => void }) {
  useKeyboardShortcuts(overlay, setOverlay)
  return (
    <>
      {overlay === 'search' && <SearchOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'toc' && <TocOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'history' && <HistoryOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'shortcuts' && <ShortcutsOverlay onClose={() => setOverlay(null)} />}
      {overlay === 'settings' && <SettingsPopover onClose={() => setOverlay(null)} />}
      {/* One row, so the buttons space themselves instead of each carrying a
          hand-picked `right` offset. */}
      <div className="corner-actions">
        <button className="corner-btn" title="Settings" aria-label="Settings" onClick={() => setOverlay('settings')}><SettingsIcon /></button>
        <button className="corner-btn" title="History (h)" aria-label="History" onClick={() => setOverlay('history')}><HistoryIcon /></button>
        <button className="corner-btn" title="Contents (t)" aria-label="Contents" onClick={() => setOverlay('toc')}><ContentsIcon /></button>
        <button className="corner-btn" title="Search (⌘K)" aria-label="Search" onClick={() => setOverlay('search')}><SearchIcon /></button>
        <BookmarkButton />
      </div>
    </>
  )
}
