/**
 * Map a DOM selection boundary back to a character offset in the stored verse
 * text, which is what highlights are keyed on.
 *
 * A poetic verse renders as several `.poem-line` blocks whose text has the
 * newline and indent spaces stripped, so the rendered text is shorter than the
 * stored text. Each line carries its own base offset; resolve the boundary
 * inside its line and add that base back.
 */

const toElement = (n: Node): Element | null =>
  n.nodeType === Node.ELEMENT_NODE ? (n as Element) : n.parentElement

/** Rendered text length from the start of `scope` up to the boundary. */
function lengthUpTo(scope: Node, node: Node, offset: number): number | null {
  const r = document.createRange()
  r.selectNodeContents(scope)
  try { r.setEnd(node, offset) } catch { return null }
  const frag = r.cloneContents()
  frag.querySelectorAll('sup.verse-num').forEach((s) => s.remove())
  return frag.textContent?.length ?? 0
}

/** Length of the verse's stored text, as recorded when it was rendered. */
export function verseTextLength(verseEl: Element): number {
  const declared = Number((verseEl as HTMLElement).dataset.len)
  if (Number.isFinite(declared) && declared > 0) return declared
  const clone = verseEl.cloneNode(true) as Element
  clone.querySelectorAll('sup.verse-num').forEach((s) => s.remove())
  return clone.textContent?.length ?? 0
}

export function offsetInVerse(verseEl: Element, node: Node, offset: number, fallback: number): number {
  const line = toElement(node)?.closest('.poem-line')
  if (line && verseEl.contains(line)) {
    const within = lengthUpTo(line, node, offset)
    return within === null ? fallback : Number((line as HTMLElement).dataset.offset ?? 0) + within
  }
  // Outside any poetic line. For prose the rendered text matches the stored
  // text one-for-one; for a poem there is no line to anchor to, so give up.
  if (verseEl.querySelector('.poem-line')) return fallback
  return lengthUpTo(verseEl, node, offset) ?? fallback
}
