import { PrefsProvider } from './state/prefs'

export default function App() {
  return (
    <PrefsProvider>
      <div style={{ padding: 40 }}>Zephyr</div>
    </PrefsProvider>
  )
}
