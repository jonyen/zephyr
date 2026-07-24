const ROWS: Array<[string, string]> = [
  ['⌘K or /', 'Search'], ['←  →', 'Previous / next chapter'], ['t', 'Table of contents'],
  ['h', 'Reading history'], ['⌘D', 'Bookmark chapter'], ['?', 'This overlay'], ['Esc', 'Close overlays'],
]
export default function ShortcutsOverlay({ onClose }: { onClose: () => void }) {
  return (
    <div className="overlay-backdrop" onClick={onClose}>
      <div className="toc-box shortcuts-box" onClick={(e) => e.stopPropagation()}>
        <table>
          <tbody>
            {ROWS.map(([k, d]) => <tr key={k}><td className="key">{k}</td><td>{d}</td></tr>)}
          </tbody>
        </table>
      </div>
    </div>
  )
}
