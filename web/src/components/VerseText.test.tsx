import { describe, it, expect } from 'vitest'
import { render } from '@testing-library/react'
import VerseText from './VerseText'
import { layoutVerses } from '../lib/poetry'
import { offsetInVerse, verseTextLength } from '../lib/verse-offsets'

const PSALM_23 = [
  { number: 1, text: 'The Lord is my shepherd; I shall not want.' },
  { number: 2, text: 'He makes me lie down in green pastures.\nHe leads me beside still waters.' },
  { number: 3, text: "He restores my soul.\nHe leads me in paths of righteousness\n    for his name's sake." },
]

const MATTHEW_6 = [
  { number: 13, text: 'And lead us not into temptation,\n    but deliver us from evil.' },
  { number: 14, text: 'For if you forgive others their trespasses, your heavenly Father will also forgive you,' },
]

function renderVerses(verses: { number: number; text: string }[]) {
  const layout = layoutVerses(verses)
  const { container } = render(
    <>{layout.map((v) => <VerseText key={v.number} verse={v} isRed={false} highlights={[]} bionic={false} />)}</>,
  )
  return container
}

const verseEl = (c: HTMLElement, n: number) => c.querySelector(`.verse[data-verse="${n}"]`)!

function renderHighlighted(verse: { number: number; text: string }, startChar: number, endChar: number) {
  const [layout] = layoutVerses([verse])
  const { container } = render(
    <VerseText
      verse={layout}
      isRed={false}
      bionic={false}
      highlights={[{ book: 'Psalm', chapter: 23, verse: verse.number, startChar, endChar, color: 'yellow' }]}
    />,
  )
  return [...container.querySelectorAll('mark.hl')].map((m) => m.textContent).join('\u0001')
}

describe('VerseText poetry rendering', () => {
  it('gives each poetic line its own block at the right indent level', () => {
    const c = renderVerses(PSALM_23)
    const lines = [...c.querySelectorAll<HTMLElement>('.poem-line')]
    expect(lines.map((l) => l.textContent)).toEqual([
      '1The Lord is my shepherd; I shall not want.',
      '2He makes me lie down in green pastures.',
      'He leads me beside still waters.',
      '3He restores my soul.',
      'He leads me in paths of righteousness',
      "for his name's sake.",
    ])
    expect(lines.map((l) => l.dataset.indent)).toEqual(['0', '0', '0', '0', '0', '1'])
  })

  it('renders the verse number once, on the first line only', () => {
    const c = renderVerses(PSALM_23)
    expect(verseEl(c, 3).querySelectorAll('sup.verse-num')).toHaveLength(1)
  })

  it('leaves prose as inline text with no poem lines', () => {
    const c = renderVerses(MATTHEW_6)
    expect(verseEl(c, 14).querySelector('.poem-line')).toBeNull()
    expect(verseEl(c, 13).querySelectorAll('.poem-line')).toHaveLength(2)
  })

  it('records the stored text length, not the rendered length', () => {
    const c = renderVerses(PSALM_23)
    const el = verseEl(c, 3)
    expect(verseTextLength(el)).toBe(PSALM_23[2].text.length)
    // The rendered text is shorter: the newlines and indent spaces are gone.
    expect(el.textContent!.length).toBeLessThan(PSALM_23[2].text.length)
  })
})

describe('offsetInVerse round-trip', () => {
  /** Resolve a selection boundary the way SelectionToolbar does. */
  function offsetOf(el: Element, lineIndex: number, charInLine: number, fallback = 0) {
    const scope = el.querySelectorAll('.poem-line')[lineIndex] ?? el
    const walker = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT)
    let seen = 0
    while (walker.nextNode()) {
      const node = walker.currentNode as Text
      if (node.parentElement?.closest('sup.verse-num')) continue
      if (seen + node.length >= charInLine) return offsetInVerse(el, node, charInLine - seen, fallback)
      seen += node.length
    }
    throw new Error('boundary past end of line')
  }

  it('maps a boundary on the first poetic line to the same offset as the stored text', () => {
    const c = renderVerses(PSALM_23)
    const el = verseEl(c, 3)
    expect(offsetOf(el, 0, 'He restores'.length)).toBe(11)
  })

  it('adds the line base back for a boundary on a later poetic line', () => {
    const c = renderVerses(PSALM_23)
    const text = PSALM_23[2].text
    const el = verseEl(c, 3)
    // 'He leads' on line two starts right after 'He restores my soul.\n'
    expect(offsetOf(el, 1, 'He leads'.length)).toBe(text.indexOf('He leads') + 'He leads'.length)
  })

  it('accounts for stripped indent spaces on an indented line', () => {
    const c = renderVerses(PSALM_23)
    const text = PSALM_23[2].text
    const el = verseEl(c, 3)
    expect(offsetOf(el, 2, 'for his'.length)).toBe(text.indexOf('for his') + 'for his'.length)
  })

  it('still resolves offsets inside a prose verse', () => {
    const c = renderVerses(MATTHEW_6)
    const el = verseEl(c, 14)
    expect(offsetOf(el, -1, 'For if you forgive'.length)).toBe('For if you forgive'.length)
  })

  it('falls back when the boundary is inside a poem but outside every line', () => {
    const c = renderVerses(PSALM_23)
    const el = verseEl(c, 3)
    expect(offsetInVerse(el, el, 0, 99)).toBe(99)
  })
})

describe('highlights across poetic lines', () => {
  const V3 = PSALM_23[2]

  it('paints a range that sits inside one line', () => {
    expect(renderHighlighted(V3, 0, 'He restores'.length)).toBe('He restores')
  })

  it('splits a range that spans a line break, dropping the newline itself', () => {
    const end = V3.text.indexOf('He leads') + 'He leads'.length
    expect(renderHighlighted(V3, 'He '.length, end)).toBe('restores my soul.\u0001He leads')
  })

  it('drops the stripped indent spaces from a range covering an indented line', () => {
    const start = V3.text.indexOf('righteousness')
    expect(renderHighlighted(V3, start, V3.text.length)).toBe("righteousness\u0001for his name's sake.")
  })

  it('leaves lines outside the range unpainted', () => {
    expect(renderHighlighted(V3, 0, 5)).toBe('He re')
  })
})
