export function bionicWords(text: string): Array<{ bold: string; rest: string }> {
  if (!text) return []
  const tokens = text.split(/(\s+)/)
  const out: Array<{ bold: string; rest: string }> = []
  for (const tok of tokens) {
    if (!tok) continue
    if (/^\s+$/.test(tok)) {
      if (out.length) out[out.length - 1].rest += tok
      else out.push({ bold: '', rest: tok })
    } else {
      const n = Math.ceil(tok.length * 0.4)
      out.push({ bold: tok.slice(0, n), rest: tok.slice(n) })
    }
  }
  return out
}
