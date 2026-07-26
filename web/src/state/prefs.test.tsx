import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { PrefsProvider, usePrefs } from './prefs'

beforeEach(() => localStorage.clear())
const wrapper = ({ children }: { children: React.ReactNode }) => <PrefsProvider>{children}</PrefsProvider>

describe('prefs', () => {
  it('defaults and persists', () => {
    const { result } = renderHook(() => usePrefs(), { wrapper })
    expect(result.current.prefs.font).toBe('georgia')
    act(() => result.current.setPref('theme', 'sepia'))
    expect(document.documentElement.dataset.theme).toBe('sepia')
    expect(JSON.parse(localStorage.getItem('zephyr.v1.prefs')!)).toMatchObject({ theme: 'sepia' })
  })
})
