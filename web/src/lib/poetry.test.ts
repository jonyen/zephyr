import { describe, it, expect } from 'vitest'
import { isPoetry, layoutVerses, verseLines } from './poetry'

const v = (number: number, text: string) => ({ number, text })

describe('isPoetry', () => {
  it('is true when the verse carries an internal line break', () => {
    expect(isPoetry('He makes me lie down in green pastures.\nHe leads me beside still waters.')).toBe(true)
  })

  it('is false for a single-line verse', () => {
    expect(isPoetry('The Lord is my shepherd; I shall not want.')).toBe(false)
  })
})

describe('verseLines', () => {
  it('returns the whole verse as one flush line when there is no break', () => {
    expect(verseLines('The Lord is my shepherd.')).toEqual([
      { text: 'The Lord is my shepherd.', offset: 0, indent: 0 },
    ])
  })

  it('strips the leading indent spaces and records the indent level', () => {
    expect(verseLines('Your kingdom come,\n    your will be done,\n        on earth.')).toEqual([
      { text: 'Your kingdom come,', offset: 0, indent: 0 },
      { text: 'your will be done,', offset: 23, indent: 1 },
      { text: 'on earth.', offset: 50, indent: 2 },
    ])
  })

  it('records offsets that slice the original verse text exactly', () => {
    const text = "He restores my soul.\nHe leads me in paths of righteousness\n    for his name's sake."
    for (const line of verseLines(text)) {
      expect(text.slice(line.offset, line.offset + line.text.length)).toBe(line.text)
    }
  })
})

describe('layoutVerses', () => {
  it('leaves consecutive prose verses as prose', () => {
    const out = layoutVerses([v(1, 'In the beginning,'), v(2, 'The earth was without form.')])
    expect(out.map((l) => l.poetry)).toEqual([false, false])
  })

  it('lays out every verse of a poem as poetry', () => {
    // Psalm 23:1-3
    const out = layoutVerses([
      v(1, 'The Lord is my shepherd; I shall not want.'),
      v(2, 'He makes me lie down in green pastures.\nHe leads me beside still waters.'),
      v(3, "He restores my soul.\nHe leads me in paths of righteousness\n    for his name's sake."),
    ])
    expect(out.map((l) => l.poetry)).toEqual([true, true, true])
    expect(out.flatMap((l) => l.lines.map((n) => n.text))).toEqual([
      'The Lord is my shepherd; I shall not want.',
      'He makes me lie down in green pastures.',
      'He leads me beside still waters.',
      'He restores my soul.',
      'He leads me in paths of righteousness',
      "for his name's sake.",
    ])
  })

  it('treats a single-line verse sandwiched between poem verses as poetry', () => {
    // Matthew 6:10-12 — verse 11 is one unbroken petition
    const out = layoutVerses([
      v(10, 'Your kingdom come,\n    your will be done,'),
      v(11, 'Give us this day our daily bread,'),
      v(12, 'and forgive us our debts,\n    as we also have forgiven our debtors.'),
    ])
    expect(out.map((l) => l.poetry)).toEqual([true, true, true])
  })

  it('leaves prose that follows a poem as prose', () => {
    // Matthew 6:13-15 — the prose paragraph resumes at 14
    const out = layoutVerses([
      v(13, 'And lead us not into temptation,\n    but deliver us from evil.'),
      v(14, 'For if you forgive others their trespasses,'),
      v(15, 'but if you do not forgive others their trespasses,'),
    ])
    expect(out.map((l) => l.poetry)).toEqual([true, false, false])
  })

  it('skips verses the ESV omits, leaving no blank line behind', () => {
    const out = layoutVerses([
      v(43, 'where their worm does not die.'),
      v(44, ''),
      v(45, 'And if your foot causes you to sin.'),
    ])
    expect(out.map((l) => l.number)).toEqual([43, 45])
  })

  it('does not let an omitted verse break a poem in two', () => {
    const out = layoutVerses([
      v(1, 'Praise the Lord!\n    Praise God in his sanctuary;'),
      v(2, ''),
      v(3, 'Praise him with trumpet sound;\n    praise him with lute and harp!'),
    ])
    expect(out.map((l) => l.poetry)).toEqual([true, true])
  })

  it('returns nothing for an empty chapter', () => {
    expect(layoutVerses([])).toEqual([])
  })
})
