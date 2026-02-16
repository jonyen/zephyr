"use client";

import { useState, useCallback, useEffect, useRef } from "react";
import type { Chapter, Highlight, HighlightColor } from "@/lib/types";

interface ChapterViewProps {
  chapter: Chapter;
  bookName: string;
  highlights: Highlight[];
  bookmarked: boolean;
  redLetterVerses: number[];
  highlightVerseStart?: number | null;
  highlightVerseEnd?: number | null;
  onAddHighlight: (
    verse: number,
    startChar: number,
    endChar: number,
    color: HighlightColor,
  ) => void;
  onRemoveHighlight: (
    verse: number,
    startChar: number,
    endChar: number,
  ) => void;
}

const HIGHLIGHT_BG: Record<HighlightColor, string> = {
  yellow: "bg-yellow-200",
  green: "bg-green-200",
  blue: "bg-blue-200",
  pink: "bg-pink-200",
};

const HIGHLIGHT_COLORS: { color: HighlightColor; label: string }[] = [
  { color: "yellow", label: "Highlight Yellow" },
  { color: "green", label: "Highlight Green" },
  { color: "blue", label: "Highlight Blue" },
  { color: "pink", label: "Highlight Pink" },
];

interface ContextMenuState {
  x: number;
  y: number;
  verse: number;
  startChar: number;
  endChar: number;
}

/** Segment of verse text with optional styling */
interface TextSegment {
  text: string;
  startChar: number;
  highlight?: HighlightColor;
  redLetter: boolean;
  searchHighlight: boolean;
}

/**
 * Split verse text into styled segments based on highlights, red letter, and
 * search highlighting.
 */
function buildSegments(
  text: string,
  verseHighlights: Highlight[],
  isRedLetter: boolean,
  isSearchHighlighted: boolean,
): TextSegment[] {
  if (text.length === 0) return [];

  // Build a per-character color map from highlights
  const charColors: (HighlightColor | null)[] = new Array(text.length).fill(
    null,
  );
  for (const h of verseHighlights) {
    const start = Math.max(0, h.startChar);
    const end = Math.min(text.length, h.endChar);
    for (let i = start; i < end; i++) {
      charColors[i] = h.color;
    }
  }

  // Determine red-letter start offset
  let redLetterStart = -1;
  if (isRedLetter) {
    const quoteIdx = text.indexOf("\u201C");
    redLetterStart = quoteIdx >= 0 ? quoteIdx : 0;
  }

  // Walk through characters and group into segments
  const segments: TextSegment[] = [];
  let i = 0;
  while (i < text.length) {
    const hl = charColors[i];
    const red = isRedLetter && i >= redLetterStart;

    let j = i + 1;
    while (j < text.length) {
      if (charColors[j] !== hl) break;
      const nextRed = isRedLetter && j >= redLetterStart;
      if (nextRed !== red) break;
      j++;
    }

    segments.push({
      text: text.slice(i, j),
      startChar: i,
      highlight: hl ?? undefined,
      redLetter: red,
      searchHighlight: isSearchHighlighted,
    });
    i = j;
  }

  return segments;
}

/**
 * Resolve the verse and character offset from a DOM node + offset within the
 * chapter container. We walk up from the node to find the closest
 * `[data-verse]` span, then compute the character offset within that verse's
 * text content by traversing only the `.verse-text` children (skipping the
 * superscript verse number).
 */
function resolveVerseOffset(
  node: Node,
  offset: number,
): { verse: number; charOffset: number } | null {
  // Find the ancestor span[data-verse]
  let el: Node | null = node;
  while (el && !(el instanceof HTMLElement && el.dataset.verse)) {
    el = el.parentElement;
  }
  if (!el || !(el instanceof HTMLElement)) return null;

  const verse = parseInt(el.dataset.verse!, 10);
  if (isNaN(verse)) return null;

  // Find the .verse-text container within this verse span
  const verseTextEl = el.querySelector(".verse-text");
  if (!verseTextEl) return null;

  // Compute the character offset within the verse-text element
  const charOffset = getCharOffset(verseTextEl, node, offset);
  return charOffset >= 0 ? { verse, charOffset } : null;
}

/**
 * Calculate the character offset of (node, offset) relative to the start of
 * the container element by walking the DOM tree in order.
 */
function getCharOffset(
  container: Node,
  targetNode: Node,
  targetOffset: number,
): number {
  let count = 0;

  const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT);
  let current = walker.nextNode();
  while (current) {
    if (current === targetNode) {
      return count + targetOffset;
    }
    count += (current.textContent?.length ?? 0);
    current = walker.nextNode();
  }

  // targetNode might be the container itself (e.g. when selecting an element node)
  // In that case offset refers to child index — approximate with total text length
  if (targetNode === container) {
    // offset is the child index; compute text length up to that child
    let total = 0;
    for (let i = 0; i < targetOffset && i < container.childNodes.length; i++) {
      total += (container.childNodes[i].textContent?.length ?? 0);
    }
    return total;
  }

  return -1;
}

export default function ChapterView({
  chapter,
  bookName,
  highlights,
  bookmarked,
  redLetterVerses,
  highlightVerseStart,
  highlightVerseEnd,
  onAddHighlight,
  onRemoveHighlight,
}: ChapterViewProps) {
  const [contextMenu, setContextMenu] = useState<ContextMenuState | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Close context menu on click outside or scroll
  useEffect(() => {
    if (!contextMenu) return;

    const close = () => setContextMenu(null);
    window.addEventListener("click", close);
    window.addEventListener("scroll", close, true);
    return () => {
      window.removeEventListener("click", close);
      window.removeEventListener("scroll", close, true);
    };
  }, [contextMenu]);

  const handleContextMenu = useCallback(
    (e: React.MouseEvent) => {
      const selection = window.getSelection();
      if (!selection || selection.isCollapsed) return;

      const anchorNode = selection.anchorNode;
      const focusNode = selection.focusNode;
      if (!anchorNode || !focusNode) return;

      const start = resolveVerseOffset(anchorNode, selection.anchorOffset);
      const end = resolveVerseOffset(focusNode, selection.focusOffset);
      if (!start || !end) return;

      // For simplicity, only support single-verse highlights
      if (start.verse !== end.verse) return;

      const startChar = Math.min(start.charOffset, end.charOffset);
      const endChar = Math.max(start.charOffset, end.charOffset);
      if (startChar === endChar) return;

      e.preventDefault();
      setContextMenu({
        x: e.clientX,
        y: e.clientY,
        verse: start.verse,
        startChar,
        endChar,
      });
    },
    [],
  );

  const handleHighlightAction = useCallback(
    (color: HighlightColor) => {
      if (!contextMenu) return;
      onAddHighlight(contextMenu.verse, contextMenu.startChar, contextMenu.endChar, color);
      setContextMenu(null);
    },
    [contextMenu, onAddHighlight],
  );

  const handleRemoveHighlight = useCallback(() => {
    if (!contextMenu) return;
    onRemoveHighlight(contextMenu.verse, contextMenu.startChar, contextMenu.endChar);
    setContextMenu(null);
  }, [contextMenu, onRemoveHighlight]);

  const redLetterSet = new Set(redLetterVerses);

  return (
    <div ref={containerRef} className="px-6 pt-6 pb-6 border-b border-stone-200">
      {/* Chapter title */}
      <h2 className="text-2xl font-semibold mb-4 flex items-center gap-2">
        {bookName} {chapter.number}
        {bookmarked && (
          <span className="text-lg" aria-label="Bookmarked">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              className="w-5 h-5 text-amber-500 inline-block"
            >
              <path
                fillRule="evenodd"
                d="M6.32 2.577a49.255 49.255 0 0111.36 0c1.497.174 2.57 1.46 2.57 2.93V21a.75.75 0 01-1.085.67L12 18.089l-7.165 3.583A.75.75 0 013.75 21V5.507c0-1.47 1.073-2.756 2.57-2.93z"
                clipRule="evenodd"
              />
            </svg>
          </span>
        )}
      </h2>

      {/* Verses */}
      <div
        className="font-serif text-base leading-relaxed"
        onContextMenu={handleContextMenu}
      >
        {chapter.verses.map((verse) => {
          const verseHighlights = highlights.filter(
            (h) => h.verse === verse.number,
          );
          const isRedLetter = redLetterSet.has(verse.number);
          const isSearchHighlighted =
            highlightVerseStart != null &&
            highlightVerseEnd != null &&
            verse.number >= highlightVerseStart &&
            verse.number <= highlightVerseEnd;

          const segments = buildSegments(
            verse.text,
            verseHighlights,
            isRedLetter,
            isSearchHighlighted,
          );

          return (
            <span key={verse.number} data-verse={verse.number} className="verse">
              {/* Verse number */}
              <sup className="text-xs text-stone-400 align-super mr-0.5 select-none">
                {verse.number}
              </sup>
              {/* Verse text */}
              <span className="verse-text">
                {segments.map((seg, idx) => {
                  const classes: string[] = [];
                  if (seg.highlight) classes.push(HIGHLIGHT_BG[seg.highlight]);
                  if (seg.redLetter) classes.push("text-red-600");
                  if (seg.searchHighlight) classes.push("text-blue-600");

                  return classes.length > 0 ? (
                    <span key={idx} className={classes.join(" ")}>
                      {seg.text}
                    </span>
                  ) : (
                    <span key={idx}>{seg.text}</span>
                  );
                })}
              </span>
              {/* Space between verses */}
              {" "}
            </span>
          );
        })}
      </div>

      {/* Context menu */}
      {contextMenu && (
        <div
          className="fixed z-50 bg-white rounded-lg shadow-lg border border-stone-200 py-1 min-w-[180px]"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          onClick={(e) => e.stopPropagation()}
        >
          {HIGHLIGHT_COLORS.map(({ color, label }) => (
            <button
              key={color}
              className="w-full text-left px-4 py-1.5 text-sm hover:bg-stone-100 flex items-center gap-2"
              onClick={() => handleHighlightAction(color)}
            >
              <span
                className={`inline-block w-3 h-3 rounded-sm ${HIGHLIGHT_BG[color]}`}
              />
              {label}
            </button>
          ))}
          <div className="border-t border-stone-200 my-1" />
          <button
            className="w-full text-left px-4 py-1.5 text-sm hover:bg-stone-100"
            onClick={handleRemoveHighlight}
          >
            Remove Highlight
          </button>
          <button
            className="w-full text-left px-4 py-1.5 text-sm hover:bg-stone-100"
            onClick={() => {
              document.execCommand("copy");
              setContextMenu(null);
            }}
          >
            Copy
          </button>
        </div>
      )}
    </div>
  );
}
