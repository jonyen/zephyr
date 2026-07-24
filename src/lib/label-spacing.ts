/** Port of the native BibleScrubber.spacedLabelFractions (forward+backward min-gap pass). */
export function spaceLabels(midFractions: number[], trackHeightPx: number, minGapPx = 20): number[] {
  const gap = trackHeightPx > 0 ? minGapPx / trackHeightPx : 0
  const out = [...midFractions]
  for (let i = 1; i < out.length; i++) {
    if (out[i] < out[i - 1] + gap) out[i] = out[i - 1] + gap
  }
  if (out.length && out[out.length - 1] > 1) out[out.length - 1] = 1
  for (let i = out.length - 2; i >= 0; i--) {
    if (out[i] > out[i + 1] - gap) out[i] = out[i + 1] - gap
  }
  return out
}
