import { usePrefs } from '../state/prefs'
import MacDownloadLink from './MacDownloadLink'
import type { Prefs } from '../lib/types'

const THEMES: Prefs['theme'][] = ['system', 'light', 'dark', 'sepia', 'black']
const FONTS: Array<{ id: Prefs['font']; label: string }> = [
  { id: 'georgia', label: 'Georgia' }, { id: 'palatino', label: 'Palatino' }, { id: 'helvetica', label: 'Helvetica Neue' },
]

export default function SettingsPopover({ onClose }: { onClose: () => void }) {
  const { prefs, setPref } = usePrefs()
  return (
    <div className="popover-backdrop" onClick={onClose}>
      <div className="settings-popover" onClick={(e) => e.stopPropagation()}>
        <div className="settings-group">
          <span className="settings-label">Theme</span>
          <div className="settings-row">
            {THEMES.map((t) => (
              <button key={t} className={prefs.theme === t ? 'chip active' : 'chip'} onClick={() => setPref('theme', t)}>{t}</button>
            ))}
          </div>
        </div>
        <div className="settings-group">
          <span className="settings-label">Font</span>
          <div className="settings-row">
            {FONTS.map((f) => (
              <button key={f.id} className={prefs.font === f.id ? 'chip active' : 'chip'} onClick={() => setPref('font', f.id)}>{f.label}</button>
            ))}
          </div>
        </div>
        <div className="settings-group">
          <label className="settings-toggle"><input type="checkbox" checked={prefs.redLetter} onChange={(e) => setPref('redLetter', e.target.checked)} /> Red letter</label>
          <label className="settings-toggle"><input type="checkbox" checked={prefs.bionic} onChange={(e) => setPref('bionic', e.target.checked)} /> Bionic reading</label>
        </div>
        <MacDownloadLink />
        <p className="esv-attribution esv-attribution-settings">
          Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway. Used by permission. All rights reserved.
        </p>
      </div>
    </div>
  )
}
