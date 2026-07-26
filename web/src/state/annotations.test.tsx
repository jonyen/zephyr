import { describe, it, expect, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { AnnotationsProvider, useAnnotations } from './annotations'

beforeEach(() => localStorage.clear())
const wrapper = ({ children }: { children: React.ReactNode }) => <AnnotationsProvider>{children}</AnnotationsProvider>

describe('annotations', () => {
  it('adds and persists highlights', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 0, endChar: 10, color: 'yellow' }))
    expect(result.current.highlights).toHaveLength(1)
    expect(JSON.parse(localStorage.getItem('zephyr.v1.highlights')!)).toHaveLength(1)
  })
  it('removes overlapping highlights only', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => {
      result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 0, endChar: 10, color: 'yellow' })
      result.current.addHighlight({ book: 'John', chapter: 3, verse: 16, startChar: 20, endChar: 30, color: 'green' })
    })
    act(() => result.current.removeHighlights('John', 3, 16, 5, 8))
    expect(result.current.highlights).toHaveLength(1)
    expect(result.current.highlights[0].color).toBe('green')
  })
  it('toggles bookmarks', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => result.current.toggleBookmark('John', 3))
    expect(result.current.bookmarks).toEqual([{ book: 'John', chapter: 3 }])
    act(() => result.current.toggleBookmark('John', 3))
    expect(result.current.bookmarks).toEqual([])
  })
  it('dedupes consecutive history entries', () => {
    const { result } = renderHook(() => useAnnotations(), { wrapper })
    act(() => { result.current.logHistory('John', 3); result.current.logHistory('John', 3); result.current.logHistory('John', 4) })
    expect(result.current.history.map((h) => h.chapter)).toEqual([4, 3])
  })
})
