import { describe, it, expect } from 'vitest'
import { spaceLabels } from './label-spacing'

describe('spaceLabels', () => {
  it('leaves well-spaced labels alone', () => {
    expect(spaceLabels([0.1, 0.5, 0.9], 1000)).toEqual([0.1, 0.5, 0.9])
  })
  it('enforces min gap on crowded labels', () => {
    const out = spaceLabels([0.5, 0.5, 0.5], 1000, 20) // gap fraction 0.02
    expect(out[1] - out[0]).toBeCloseTo(0.02, 5)
    expect(out[2] - out[1]).toBeCloseTo(0.02, 5)
  })
  it('clamps the last label to 1 and pushes predecessors up', () => {
    const out = spaceLabels([0.99, 0.995, 1.0], 1000, 20)
    expect(out[2]).toBe(1)
    expect(out[2] - out[1]).toBeCloseTo(0.02, 5)
    expect(out[1] - out[0]).toBeCloseTo(0.02, 5)
  })
  it('preserves order for 66 crowded labels', () => {
    const mids = Array.from({ length: 66 }, (_, i) => i / 65)
    const out = spaceLabels(mids, 600, 20) // 66*20 > 600 → overflow expected
    for (let i = 1; i < out.length; i++) expect(out[i] - out[i - 1]).toBeGreaterThanOrEqual(0.0333 - 1e-9)
  })
})
