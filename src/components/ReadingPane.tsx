"use client";

import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import type {
  ChapterPosition,
  Bookmark,
  Highlight,
  HighlightColor,
  Chapter,
} from "@/lib/types";
import {
  loadBook,
  bookNames,
  chapterCounts,
} from "@/lib/bible-store";
import ChapterView from "./ChapterView";
import { useInfiniteScroll } from "@/hooks/useInfiniteScroll";

// ---------------------------------------------------------------------------
// Chapter navigation helpers
// ---------------------------------------------------------------------------

function chapterAfter(position: ChapterPosition): ChapterPosition | null {
  const maxChapter = chapterCounts[position.bookName] ?? 0;
  if (position.chapterNumber < maxChapter) {
    return { bookName: position.bookName, chapterNumber: position.chapterNumber + 1 };
  }
  const bookIndex = bookNames.indexOf(position.bookName);
  if (bookIndex < 0 || bookIndex >= bookNames.length - 1) return null;
  return { bookName: bookNames[bookIndex + 1], chapterNumber: 1 };
}

function chapterBefore(position: ChapterPosition): ChapterPosition | null {
  if (position.chapterNumber > 1) {
    return { bookName: position.bookName, chapterNumber: position.chapterNumber - 1 };
  }
  const bookIndex = bookNames.indexOf(position.bookName);
  if (bookIndex <= 0) return null;
  const prevBook = bookNames[bookIndex - 1];
  return { bookName: prevBook, chapterNumber: chapterCounts[prevBook] ?? 1 };
}

function posKey(p: ChapterPosition): string {
  return `${p.bookName}:${p.chapterNumber}`;
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface ReadingPaneProps {
  initialPosition: ChapterPosition;
  navigationId: number;
  highlightVerseStart?: number | null;
  highlightVerseEnd?: number | null;
  bookmarks: Bookmark[];
  highlights: Highlight[];
  redLetterData: Record<string, Record<string, number[]>>;
  onPositionChanged: (position: ChapterPosition) => void;
  onAddHighlight: (
    book: string,
    chapter: number,
    verse: number,
    startChar: number,
    endChar: number,
    color: HighlightColor,
  ) => void;
  onRemoveHighlight: (
    book: string,
    chapter: number,
    verse: number,
    startChar: number,
    endChar: number,
  ) => void;
}

// ---------------------------------------------------------------------------
// Loaded chapter data
// ---------------------------------------------------------------------------

interface LoadedChapter {
  position: ChapterPosition;
  chapter: Chapter;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function ReadingPane({
  initialPosition,
  navigationId,
  highlightVerseStart,
  highlightVerseEnd,
  bookmarks,
  highlights,
  redLetterData,
  onPositionChanged,
  onAddHighlight,
  onRemoveHighlight,
}: ReadingPaneProps) {
  const [loadedChapters, setLoadedChapters] = useState<LoadedChapter[]>([]);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const chapterDivsRef = useRef<Map<string, HTMLDivElement>>(new Map());
  const isPrependingRef = useRef(false);
  const loadingRef = useRef<Set<string>>(new Set());

  // -----------------------------------------------------------------------
  // Reset when navigation changes
  // -----------------------------------------------------------------------

  useEffect(() => {
    setLoadedChapters([]);
    loadingRef.current.clear();
    const key = posKey(initialPosition);
    loadingRef.current.add(key);

    loadBook(initialPosition.bookName).then((book) => {
      if (!book) {
        loadingRef.current.delete(key);
        return;
      }
      const ch = book.chapters.find(
        (c) => c.number === initialPosition.chapterNumber,
      );
      if (!ch) {
        loadingRef.current.delete(key);
        return;
      }
      setLoadedChapters([{ position: initialPosition, chapter: ch }]);
      loadingRef.current.delete(key);
      // Scroll to top on navigation
      requestAnimationFrame(() => {
        scrollContainerRef.current?.scrollTo(0, 0);
      });
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [navigationId, initialPosition.bookName, initialPosition.chapterNumber]);

  // -----------------------------------------------------------------------
  // Load a chapter and add it to the list
  // -----------------------------------------------------------------------

  const appendChapter = useCallback(() => {
    if (loadedChapters.length === 0) return;
    const lastPos = loadedChapters[loadedChapters.length - 1].position;
    const next = chapterAfter(lastPos);
    if (!next) return;
    const key = posKey(next);
    if (loadingRef.current.has(key)) return;
    if (loadedChapters.some((lc) => posKey(lc.position) === key)) return;

    loadingRef.current.add(key);
    loadBook(next.bookName).then((book) => {
      if (!book) {
        loadingRef.current.delete(key);
        return;
      }
      const ch = book.chapters.find((c) => c.number === next.chapterNumber);
      if (!ch) {
        loadingRef.current.delete(key);
        return;
      }
      setLoadedChapters((prev) => {
        if (prev.some((lc) => posKey(lc.position) === key)) return prev;
        return [...prev, { position: next, chapter: ch }];
      });
      loadingRef.current.delete(key);
    });
  }, [loadedChapters]);

  const prependChapter = useCallback(() => {
    if (loadedChapters.length === 0) return;
    const firstPos = loadedChapters[0].position;
    const prev = chapterBefore(firstPos);
    if (!prev) return;
    const key = posKey(prev);
    if (loadingRef.current.has(key)) return;
    if (loadedChapters.some((lc) => posKey(lc.position) === key)) return;

    loadingRef.current.add(key);
    loadBook(prev.bookName).then((book) => {
      if (!book) {
        loadingRef.current.delete(key);
        return;
      }
      const ch = book.chapters.find((c) => c.number === prev.chapterNumber);
      if (!ch) {
        loadingRef.current.delete(key);
        return;
      }

      isPrependingRef.current = true;
      setLoadedChapters((currentChapters) => {
        if (currentChapters.some((lc) => posKey(lc.position) === key))
          return currentChapters;
        return [{ position: prev, chapter: ch }, ...currentChapters];
      });
      loadingRef.current.delete(key);
    });
  }, [loadedChapters]);

  // -----------------------------------------------------------------------
  // Preserve scroll position when prepending
  // -----------------------------------------------------------------------

  useEffect(() => {
    if (!isPrependingRef.current) return;
    isPrependingRef.current = false;

    const container = scrollContainerRef.current;
    if (!container) return;

    // We need to measure after React has committed to the DOM.
    // requestAnimationFrame fires after the paint, so we can measure.
    requestAnimationFrame(() => {
      // The first chapter div is the newly prepended one.
      // We want to keep the previously-first chapter in the same visual position.
      // Since the new content was added at the top, we adjust scrollTop by the
      // height of the new content.
      if (loadedChapters.length < 2) return;
      const newFirstKey = posKey(loadedChapters[0].position);
      const newFirstDiv = chapterDivsRef.current.get(newFirstKey);
      if (newFirstDiv) {
        container.scrollTop += newFirstDiv.offsetHeight;
      }
    });
  }, [loadedChapters]);

  // -----------------------------------------------------------------------
  // Can load more?
  // -----------------------------------------------------------------------

  const canLoadPrevious = useMemo(() => {
    if (loadedChapters.length === 0) return false;
    return chapterBefore(loadedChapters[0].position) !== null;
  }, [loadedChapters]);

  const canLoadNext = useMemo(() => {
    if (loadedChapters.length === 0) return false;
    return chapterAfter(loadedChapters[loadedChapters.length - 1].position) !== null;
  }, [loadedChapters]);

  // -----------------------------------------------------------------------
  // Infinite scroll hook
  // -----------------------------------------------------------------------

  const { topSentinelRef, bottomSentinelRef } = useInfiniteScroll({
    onLoadPrevious: prependChapter,
    onLoadNext: appendChapter,
    scrollContainer: scrollContainerRef.current,
    canLoadPrevious,
    canLoadNext,
  });

  // -----------------------------------------------------------------------
  // Track topmost visible chapter to report position changes
  // -----------------------------------------------------------------------

  useEffect(() => {
    const container = scrollContainerRef.current;
    if (!container || loadedChapters.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        // Find the topmost visible chapter
        let topmost: { position: ChapterPosition; top: number } | null = null;
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const el = entry.target as HTMLElement;
          const book = el.dataset.book;
          const chapter = el.dataset.chapter;
          if (!book || !chapter) continue;
          const rect = entry.boundingClientRect;
          if (!topmost || rect.top < topmost.top) {
            topmost = {
              position: { bookName: book, chapterNumber: parseInt(chapter, 10) },
              top: rect.top,
            };
          }
        }
        if (topmost) {
          onPositionChanged(topmost.position);
        }
      },
      {
        root: container,
        rootMargin: "0px",
        threshold: 0,
      },
    );

    // Observe all chapter divs
    chapterDivsRef.current.forEach((div) => observer.observe(div));

    return () => observer.disconnect();
  }, [loadedChapters, onPositionChanged]);

  // -----------------------------------------------------------------------
  // Ref callback for chapter divs
  // -----------------------------------------------------------------------

  const setChapterDivRef = useCallback(
    (key: string, el: HTMLDivElement | null) => {
      if (el) {
        chapterDivsRef.current.set(key, el);
      } else {
        chapterDivsRef.current.delete(key);
      }
    },
    [],
  );

  // -----------------------------------------------------------------------
  // Render
  // -----------------------------------------------------------------------

  return (
    <div
      ref={scrollContainerRef}
      className="flex-1 overflow-y-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
    >
      {/* Top sentinel for infinite scroll */}
      <div ref={topSentinelRef} className="h-px" aria-hidden="true" />

      <div className="max-w-3xl mx-auto">
        {loadedChapters.map((lc, index) => {
          const key = posKey(lc.position);
          const chapterHighlights = highlights.filter(
            (h) =>
              h.book === lc.position.bookName &&
              h.chapter === lc.position.chapterNumber,
          );
          const isBookmarked = bookmarks.some(
            (b) =>
              b.book === lc.position.bookName &&
              b.chapter === lc.position.chapterNumber,
          );
          const redLetterVerses =
            redLetterData[lc.position.bookName]?.[
              String(lc.position.chapterNumber)
            ] ?? [];

          // Only pass verse highlights to the initial chapter
          const isInitialChapter =
            lc.position.bookName === initialPosition.bookName &&
            lc.position.chapterNumber === initialPosition.chapterNumber;

          return (
            <div
              key={key}
              ref={(el) => setChapterDivRef(key, el)}
              data-book={lc.position.bookName}
              data-chapter={lc.position.chapterNumber}
            >
              <ChapterView
                chapter={lc.chapter}
                bookName={lc.position.bookName}
                highlights={chapterHighlights}
                bookmarked={isBookmarked}
                redLetterVerses={redLetterVerses}
                highlightVerseStart={
                  isInitialChapter ? highlightVerseStart : null
                }
                highlightVerseEnd={
                  isInitialChapter ? highlightVerseEnd : null
                }
                onAddHighlight={(verse, startChar, endChar, color) =>
                  onAddHighlight(
                    lc.position.bookName,
                    lc.position.chapterNumber,
                    verse,
                    startChar,
                    endChar,
                    color,
                  )
                }
                onRemoveHighlight={(verse, startChar, endChar) =>
                  onRemoveHighlight(
                    lc.position.bookName,
                    lc.position.chapterNumber,
                    verse,
                    startChar,
                    endChar,
                  )
                }
              />
            </div>
          );
        })}
      </div>

      {/* Bottom sentinel for infinite scroll */}
      <div ref={bottomSentinelRef} className="h-px" aria-hidden="true" />
    </div>
  );
}
