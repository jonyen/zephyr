import { useState } from 'react'
import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'
import SearchOverlay from './components/SearchOverlay'

export type OverlayName = 'search' | 'toc' | 'history' | 'settings' | 'shortcuts' | null

export default function App() {
  const [overlay, setOverlay] = useState<OverlayName>(null)
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader>
          {overlay === 'search' && <SearchOverlay onClose={() => setOverlay(null)} />}
          <button className="corner-btn" style={{ right: 44 }} title="Search (⌘K)" onClick={() => setOverlay('search')}>&#8981;</button>
        </Reader>
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
