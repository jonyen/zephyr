import { useEffect, useState } from 'react'
import { isMacDesktop, loadMacRelease, type MacRelease } from '../lib/mac-download'

// One line in the settings popover pointing macOS visitors at the native app.
//
// Renders nothing unless the visitor is on a Mac desktop AND the update manifest
// loads. Note it is therefore always absent under `npm run dev` — /zephyr-updates/
// only exists on jonyen.com. That is expected, not a bug.
export default function MacDownloadLink() {
  const [release, setRelease] = useState<MacRelease | null>(null)
  const mac = isMacDesktop()

  useEffect(() => {
    // Gate the request, not just the render: nobody on Windows or a phone should
    // pay for a fetch whose result they can never see.
    if (!mac) return
    let live = true
    loadMacRelease().then((r) => { if (live) setRelease(r) })
    return () => { live = false }
  }, [mac])

  if (!mac || !release) return null
  return (
    <a className="mac-download" href={release.dmgURL} download>
      Also for Mac — Download {release.version}
    </a>
  )
}
