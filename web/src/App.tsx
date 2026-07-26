import { useState } from 'react'
import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'
import ReaderChrome from './components/ReaderChrome'

export type OverlayName = 'search' | 'toc' | 'history' | 'settings' | 'shortcuts' | null

export default function App() {
  const [overlay, setOverlay] = useState<OverlayName>(null)
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader>
          <ReaderChrome overlay={overlay} setOverlay={setOverlay} />
        </Reader>
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
