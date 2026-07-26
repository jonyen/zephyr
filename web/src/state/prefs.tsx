import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { KEYS, loadJSON, saveJSON } from '../lib/storage'
import type { Prefs } from '../lib/types'

const DEFAULTS: Prefs = { theme: 'system', font: 'georgia', redLetter: true, bionic: false }

interface PrefsCtx { prefs: Prefs; setPref: <K extends keyof Prefs>(k: K, v: Prefs[K]) => void }
const Ctx = createContext<PrefsCtx | null>(null)

function resolveTheme(theme: Prefs['theme']): string {
  if (theme !== 'system') return theme
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [prefs, setPrefs] = useState<Prefs>(() => ({ ...DEFAULTS, ...loadJSON(KEYS.prefs, DEFAULTS) }))

  useEffect(() => {
    document.documentElement.dataset.theme = resolveTheme(prefs.theme)
    document.documentElement.dataset.font = prefs.font
    saveJSON(KEYS.prefs, prefs)
    if (prefs.theme !== 'system') return
    const mq = window.matchMedia?.('(prefers-color-scheme: dark)')
    if (!mq) return
    const onChange = () => { document.documentElement.dataset.theme = resolveTheme('system') }
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [prefs])

  const setPref: PrefsCtx['setPref'] = (k, v) => setPrefs((p) => ({ ...p, [k]: v }))
  return <Ctx.Provider value={{ prefs, setPref }}>{children}</Ctx.Provider>
}

export function usePrefs(): PrefsCtx {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('usePrefs outside PrefsProvider')
  return ctx
}
