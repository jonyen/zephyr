"use client";

import { useRef, useEffect, useState, useCallback, useMemo } from "react";
import {
  bookNames,
  chapterCounts,
  totalChapters,
  globalChapterIndex,
  chapterPosition,
} from "@/lib/bible-store";
import type { ChapterPosition, Bookmark, Highlight } from "@/lib/types";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface BibleScrubberProps {
  currentPosition: ChapterPosition;
  bookmarks: Bookmark[];
  highlights: Highlight[];
  onNavigate: (position: ChapterPosition) => void;
}

interface BookRange {
  name: string;
  startFraction: number;
  endFraction: number;
  midFraction: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const TRACK_WIDTH = 30;
const LABEL_PANEL_WIDTH = 180;
const THUMB_WIDTH = 6;
const THUMB_HEIGHT = 30;
const TICK_WIDTH = 6;
const TICK_HEIGHT = 3;
const MIN_GAP_PTS = 20;

const HIGHLIGHT_COLORS: Record<string, string> = {
  yellow: "rgba(234, 179, 8, 0.85)",
  green: "rgba(34, 197, 94, 0.85)",
  blue: "rgba(59, 130, 246, 0.8)",
  pink: "rgba(236, 72, 153, 0.85)",
};

const ACCENT_COLOR = "rgba(59, 130, 246, 1)";
const TRACK_COLOR = "rgba(128, 128, 128, 0.3)";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildBookRanges(): BookRange[] {
  const ranges: BookRange[] = [];
  let cumulative = 0;
  for (const name of bookNames) {
    const count = chapterCounts[name] ?? 0;
    const start = cumulative / totalChapters;
    cumulative += count;
    const end = cumulative / totalChapters;
    ranges.push({
      name,
      startFraction: start,
      endFraction: end,
      midFraction: (start + end) / 2,
    });
  }
  return ranges;
}

function labelScale(
  index: number,
  thumbFraction: number,
  hoveredBookIndex: number | null,
  bookRanges: BookRange[],
): number {
  if (hoveredBookIndex === index) return 2.0;
  const distance = Math.abs(bookRanges[index].midFraction - thumbFraction);
  if (distance < 0.02) return 1.6;
  if (distance < 0.05) return 1.3;
  if (distance < 0.1) return 1.1;
  return 1.0;
}

function spacedLabelFractions(
  fractions: number[],
  height: number,
): number[] {
  if (fractions.length === 0) return [];
  const minGapFraction = MIN_GAP_PTS / height;
  const result = [...fractions];

  // Forward pass: push down overlapping labels
  for (let i = 1; i < result.length; i++) {
    const minY = result[i - 1] + minGapFraction;
    if (result[i] < minY) result[i] = minY;
  }

  // Backward pass: push up if exceeded bounds
  if (result[result.length - 1] > 1) {
    result[result.length - 1] = 1;
  }
  for (let i = result.length - 2; i >= 0; i--) {
    const maxY = result[i + 1] - minGapFraction;
    if (result[i] > maxY) result[i] = maxY;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function BibleScrubber({
  currentPosition,
  bookmarks,
  highlights,
  onNavigate,
}: BibleScrubberProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [isHovering, setIsHovering] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [hoveredBookIndex, setHoveredBookIndex] = useState<number | null>(null);
  const [containerHeight, setContainerHeight] = useState(0);

  const bookRanges = useMemo(buildBookRanges, []);

  const currentFraction = useMemo(() => {
    const idx = globalChapterIndex(
      currentPosition.bookName,
      currentPosition.chapterNumber,
    );
    return idx / totalChapters;
  }, [currentPosition]);

  // Track container height via ResizeObserver
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerHeight(entry.contentRect.height);
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  // -------------------------------------------------------------------------
  // Canvas drawing
  // -------------------------------------------------------------------------

  const drawCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    const w = rect.width;
    const h = rect.height;
    const trackX = w / 2;

    ctx.clearRect(0, 0, w, h);

    // Track line
    ctx.fillStyle = TRACK_COLOR;
    ctx.fillRect(trackX - 1, 0, 2, h);

    // Highlight ticks
    for (const hl of highlights) {
      const idx = globalChapterIndex(hl.book, hl.chapter);
      const fraction = idx / totalChapters;
      const y = fraction * h;
      const color = HIGHLIGHT_COLORS[hl.color] ?? HIGHLIGHT_COLORS.yellow;
      ctx.fillStyle = color;
      roundRect(ctx, trackX - 8, y - TICK_HEIGHT / 2, TICK_WIDTH, TICK_HEIGHT, 1);
      ctx.fill();
    }

    // Bookmark diamonds
    ctx.fillStyle = ACCENT_COLOR;
    for (const bm of bookmarks) {
      const idx = globalChapterIndex(bm.book, bm.chapter);
      const fraction = idx / totalChapters;
      const y = fraction * h;
      const dx = trackX + 5;
      const size = 3;
      ctx.beginPath();
      ctx.moveTo(dx, y - size);
      ctx.lineTo(dx + size, y);
      ctx.lineTo(dx, y + size);
      ctx.lineTo(dx - size, y);
      ctx.closePath();
      ctx.fill();
    }

    // Thumb indicator
    const thumbY = currentFraction * h;
    ctx.fillStyle = ACCENT_COLOR;
    roundRect(
      ctx,
      trackX - THUMB_WIDTH / 2,
      thumbY - THUMB_HEIGHT / 2,
      THUMB_WIDTH,
      THUMB_HEIGHT,
      3,
    );
    ctx.fill();
  }, [currentFraction, bookmarks, highlights]);

  useEffect(() => {
    drawCanvas();
  }, [drawCanvas, containerHeight]);

  // -------------------------------------------------------------------------
  // Interaction handlers
  // -------------------------------------------------------------------------

  const fractionFromEvent = useCallback(
    (clientY: number): number => {
      const el = containerRef.current;
      if (!el) return 0;
      const rect = el.getBoundingClientRect();
      const y = clientY - rect.top;
      return Math.max(0, Math.min(1, y / rect.height));
    },
    [],
  );

  const navigateToFraction = useCallback(
    (fraction: number) => {
      const idx = Math.round(fraction * (totalChapters - 1));
      const pos = chapterPosition(idx);
      onNavigate(pos);
    },
    [onNavigate],
  );

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      setIsDragging(true);
      const fraction = fractionFromEvent(e.clientY);
      navigateToFraction(fraction);
    },
    [fractionFromEvent, navigateToFraction],
  );

  const handleMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (!isDragging) return;
      const fraction = fractionFromEvent(e.clientY);
      navigateToFraction(fraction);
    },
    [isDragging, fractionFromEvent, navigateToFraction],
  );

  // Global mouse events for drag
  useEffect(() => {
    if (!isDragging) return;

    const handleGlobalMove = (e: MouseEvent) => {
      const fraction = fractionFromEvent(e.clientY);
      navigateToFraction(fraction);
    };

    const handleGlobalUp = () => {
      setIsDragging(false);
    };

    window.addEventListener("mousemove", handleGlobalMove);
    window.addEventListener("mouseup", handleGlobalUp);
    return () => {
      window.removeEventListener("mousemove", handleGlobalMove);
      window.removeEventListener("mouseup", handleGlobalUp);
    };
  }, [isDragging, fractionFromEvent, navigateToFraction]);

  // -------------------------------------------------------------------------
  // Label panel
  // -------------------------------------------------------------------------

  const showLabels = isHovering || isDragging;

  const labelPositions = useMemo(() => {
    if (containerHeight <= 0) return [];
    const rawFractions = bookRanges.map((r) => r.midFraction);
    return spacedLabelFractions(rawFractions, containerHeight);
  }, [bookRanges, containerHeight]);

  const labels = useMemo(() => {
    if (!showLabels || containerHeight <= 0) return null;

    return bookRanges.map((range, i) => {
      const scale = labelScale(i, currentFraction, hoveredBookIndex, bookRanges);
      const y = labelPositions[i] * containerHeight;
      const fontSize = 11 * scale;
      const isCurrentBook = range.name === currentPosition.bookName;

      return (
        <div
          key={range.name}
          className="absolute right-0 whitespace-nowrap pr-2 cursor-pointer select-none transition-transform duration-75"
          style={{
            top: y,
            transform: "translateY(-50%)",
            fontSize: `${fontSize}px`,
            lineHeight: "1.2",
            fontWeight: isCurrentBook ? 600 : 400,
            color: isCurrentBook
              ? "rgb(59, 130, 246)"
              : "var(--foreground, #e5e5e5)",
            opacity: scale > 1.0 ? 1 : 0.7,
          }}
          onMouseEnter={() => setHoveredBookIndex(i)}
          onMouseLeave={() => setHoveredBookIndex(null)}
          onClick={() => {
            onNavigate({ bookName: range.name, chapterNumber: 1 });
          }}
        >
          {range.name}
        </div>
      );
    });
  }, [
    showLabels,
    containerHeight,
    bookRanges,
    currentFraction,
    hoveredBookIndex,
    labelPositions,
    currentPosition.bookName,
    onNavigate,
  ]);

  // Compute label panel background bounds
  const panelBounds = useMemo(() => {
    if (!showLabels || labelPositions.length === 0 || containerHeight <= 0) {
      return null;
    }
    const firstY = labelPositions[0] * containerHeight - 12;
    const lastY =
      labelPositions[labelPositions.length - 1] * containerHeight + 12;
    return { top: Math.max(0, firstY), height: lastY - firstY };
  }, [showLabels, labelPositions, containerHeight]);

  return (
    <div
      ref={containerRef}
      className="absolute right-0 top-0 bottom-0 z-40"
      style={{ width: TRACK_WIDTH }}
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => {
        setIsHovering(false);
        setHoveredBookIndex(null);
      }}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
    >
      {/* Canvas for track, ticks, bookmarks, thumb */}
      <canvas
        ref={canvasRef}
        className="absolute inset-0 w-full h-full"
        style={{ cursor: "pointer" }}
      />

      {/* Floating label panel */}
      {showLabels && (
        <div
          className="absolute top-0 bottom-0 pointer-events-none"
          style={{
            right: TRACK_WIDTH,
            width: LABEL_PANEL_WIDTH,
          }}
        >
          {/* Semi-transparent background behind labels */}
          {panelBounds && (
            <div
              className="absolute rounded-lg"
              style={{
                top: panelBounds.top,
                height: panelBounds.height,
                left: 0,
                right: 0,
                background: "rgba(30, 30, 30, 0.6)",
                backdropFilter: "blur(20px)",
                WebkitBackdropFilter: "blur(20px)",
              }}
            />
          )}

          {/* Labels */}
          <div className="relative w-full h-full pointer-events-auto">
            {labels}
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Canvas helper
// ---------------------------------------------------------------------------

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}
