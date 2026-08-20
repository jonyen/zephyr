/**
 * One icon set, drawn to one spec.
 *
 * Every icon is a 24-unit square stroked at 1.75, with round caps and joins, and
 * takes its colour from `currentColor`. That is what makes them look like a set:
 * the previous icons were five unrelated Unicode codepoints — U+2315, U+2630,
 * U+2699, U+2690 and a clock *emoji*, which macOS rendered in full colour beside
 * four monochrome glyphs, each at whatever weight its font happened to use.
 */

interface IconProps { size?: number }

const base = (size: number) => ({
  width: size,
  height: size,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.75,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
  focusable: false,
})

export function SearchIcon({ size = 17 }: IconProps) {
  return (
    <svg {...base(size)}>
      <circle cx="11" cy="11" r="6.25" />
      <path d="M15.6 15.6 20 20" />
    </svg>
  )
}

export function ContentsIcon({ size = 17 }: IconProps) {
  // Spaced 6 apart rather than 5: at 17px a 5-unit gap is barely over two
  // pixels, and the strokes silt up into a solid block.
  return (
    <svg {...base(size)}>
      <path d="M4 6h16M4 12h16M4 18h10" />
    </svg>
  )
}

export function HistoryIcon({ size = 17 }: IconProps) {
  return (
    <svg {...base(size)}>
      <circle cx="12" cy="12" r="8.25" />
      <path d="M12 7.5V12l3 1.8" />
    </svg>
  )
}

export function SettingsIcon({ size = 17 }: IconProps) {
  // Sliders rather than a gear, because a gear's teeth turn to mush at 17px —
  // but stood upright, so it cannot be mistaken for the contents list beside it.
  return (
    <svg {...base(size)}>
      <path d="M7 4v16M12 4v16M17 4v16" />
      <circle cx="7" cy="9" r="2.1" fill="var(--bg)" />
      <circle cx="12" cy="15" r="2.1" fill="var(--bg)" />
      <circle cx="17" cy="8" r="2.1" fill="var(--bg)" />
    </svg>
  )
}

export function BookmarkIcon({ size = 17, filled = false }: IconProps & { filled?: boolean }) {
  return (
    <svg {...base(size)} fill={filled ? 'currentColor' : 'none'}>
      <path d="M6.5 4.5h11a1 1 0 0 1 1 1v14l-6.5-4.2-6.5 4.2v-14a1 1 0 0 1 1-1Z" />
    </svg>
  )
}
