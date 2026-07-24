import { PrefsProvider } from './state/prefs'
import { AnnotationsProvider } from './state/annotations'
import Reader from './components/Reader'

export default function App() {
  return (
    <PrefsProvider>
      <AnnotationsProvider>
        <Reader />
      </AnnotationsProvider>
    </PrefsProvider>
  )
}
