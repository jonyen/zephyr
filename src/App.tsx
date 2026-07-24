import { useState } from 'react'
import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'
import SearchOverlay from './components/SearchOverlay'
import TocOverlay from './components/TocOverlay'

export type OverlayName = 'search' | 'toc' | 'history' | 'settings' | 'shortcuts' | null

export default function App() {
  const [overlay, setOverlay] = useState<OverlayName>(null)
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader>
          {overlay === 'search' && <SearchOverlay onClose={() => setOverlay(null)} />}
          {overlay === 'toc' && <TocOverlay onClose={() => setOverlay(null)} />}
          <button className="corner-btn" style={{ right: 44 }} title="Search (⌘K)" onClick={() => setOverlay('search')}>&#8981;</button>
          <button className="corner-btn" style={{ right: 76 }} title="Contents (t)" onClick={() => setOverlay('toc')}>☰</button>
        </Reader>
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
