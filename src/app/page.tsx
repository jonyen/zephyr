"use client";

import { useState, useEffect, useCallback } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";
import {
  globalChapterIndex,
  chapterPosition,
  bookNames,
  chapterCounts,
} from "@/lib/bible-store";
import type {
  ChapterPosition,
  Bookmark,
  Highlight,
  HistoryEntry,
  HighlightColor,
} from "@/lib/types";
import { useKeyboardShortcuts } from "@/hooks/useKeyboardShortcuts";
import ReadingPane from "@/components/ReadingPane";
import BibleScrubber from "@/components/BibleScrubber";
import SearchOverlay from "@/components/SearchOverlay";
import TOCOverlay from "@/components/TOCOverlay";
import HistorySidebar from "@/components/HistorySidebar";
import KeyboardShortcutsOverlay from "@/components/KeyboardShortcutsOverlay";

export default function Home() {
  const { user, loading } = useAuth();
  const router = useRouter();

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  const [currentPosition, setCurrentPosition] = useState<ChapterPosition>({
    bookName: "Genesis",
    chapterNumber: 1,
  });
  const [visiblePosition, setVisiblePosition] = useState<ChapterPosition>({
    bookName: "Genesis",
    chapterNumber: 1,
  });
  const [navigationCounter, setNavigationCounter] = useState(0);
  const [highlightStart, setHighlightStart] = useState<number | null>(null);
  const [highlightEnd, setHighlightEnd] = useState<number | null>(null);

  // Overlays
  const [showSearch, setShowSearch] = useState(false);
  const [showTOC, setShowTOC] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [showShortcuts, setShowShortcuts] = useState(false);

  // Data from API
  const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
  const [highlights, setHighlights] = useState<Highlight[]>([]);
  const [historyEntries, setHistoryEntries] = useState<HistoryEntry[]>([]);
  const [redLetterData, setRedLetterData] = useState<
    Record<string, Record<string, number[]>>
  >({});

  const [dataLoaded, setDataLoaded] = useState(false);

  // -------------------------------------------------------------------------
  // Auth guard
  // -------------------------------------------------------------------------

  useEffect(() => {
    if (!loading && !user) router.push("/login");
  }, [user, loading, router]);

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  useEffect(() => {
    if (!user) return;

    const load = async () => {
      try {
        const [prefsRes, bookmarksRes, highlightsRes, historyRes] =
          await Promise.all([
            fetch("/api/prefs"),
            fetch("/api/bookmarks"),
            fetch("/api/highlights"),
            fetch("/api/history"),
          ]);

        if (prefsRes.ok) {
          const prefs = await prefsRes.json();
          if (prefs.lastBook && prefs.lastChapter) {
            const pos: ChapterPosition = {
              bookName: prefs.lastBook,
              chapterNumber: prefs.lastChapter,
            };
            setCurrentPosition(pos);
            setVisiblePosition(pos);
            setNavigationCounter((c) => c + 1);
          }
        }

        if (bookmarksRes.ok) {
          setBookmarks(await bookmarksRes.json());
        }

        if (highlightsRes.ok) {
          setHighlights(await highlightsRes.json());
        }

        if (historyRes.ok) {
          setHistoryEntries(await historyRes.json());
        }

        // Load red letter data
        const redLetterModule = await import("@/data/red_letter_verses.json");
        setRedLetterData(redLetterModule.default ?? redLetterModule);
      } catch (err) {
        console.error("Failed to load data:", err);
      } finally {
        setDataLoaded(true);
      }
    };

    load();
  }, [user]);

  // -------------------------------------------------------------------------
  // Navigation functions
  // -------------------------------------------------------------------------

  const navigateTo = useCallback(
    (
      book: string,
      chapter: number,
      verseStart?: number | null,
      verseEnd?: number | null,
      addToHistory = true,
    ) => {
      setHighlightStart(verseStart ?? null);
      setHighlightEnd(verseEnd ?? null);
      setCurrentPosition({ bookName: book, chapterNumber: chapter });
      setVisiblePosition({ bookName: book, chapterNumber: chapter });
      setNavigationCounter((c) => c + 1);

      if (addToHistory) {
        fetch("/api/history", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ book, chapter, verseStart, verseEnd }),
        })
          .then((res) => (res.ok ? res.json() : null))
          .then((entry) => {
            if (entry) {
              setHistoryEntries((prev) => [entry, ...prev]);
            }
          })
          .catch(() => {});
      }

      // Save prefs
      fetch("/api/prefs", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ lastBook: book, lastChapter: chapter }),
      }).catch(() => {});
    },
    [],
  );

  const navigateChapter = useCallback(
    (delta: number) => {
      const currentIndex = globalChapterIndex(
        visiblePosition.bookName,
        visiblePosition.chapterNumber,
      );
      const newPos = chapterPosition(currentIndex + delta);
      navigateTo(newPos.bookName, newPos.chapterNumber);
    },
    [visiblePosition, navigateTo],
  );

  const navigateToBookmark = useCallback(
    (direction: 1 | -1) => {
      if (bookmarks.length === 0) return;

      const sorted = [...bookmarks].sort(
        (a, b) =>
          globalChapterIndex(a.book, a.chapter) -
          globalChapterIndex(b.book, b.chapter),
      );

      const currentIdx = globalChapterIndex(
        visiblePosition.bookName,
        visiblePosition.chapterNumber,
      );

      if (direction === 1) {
        const next = sorted.find(
          (b) => globalChapterIndex(b.book, b.chapter) > currentIdx,
        );
        const target = next ?? sorted[0];
        navigateTo(target.book, target.chapter);
      } else {
        const prev = [...sorted]
          .reverse()
          .find(
            (b) => globalChapterIndex(b.book, b.chapter) < currentIdx,
          );
        const target = prev ?? sorted[sorted.length - 1];
        navigateTo(target.book, target.chapter);
      }
    },
    [bookmarks, visiblePosition, navigateTo],
  );

  const navigateToHighlight = useCallback(
    (direction: 1 | -1) => {
      if (highlights.length === 0) return;

      const sorted = [...highlights].sort((a, b) => {
        const aIdx = globalChapterIndex(a.book, a.chapter);
        const bIdx = globalChapterIndex(b.book, b.chapter);
        if (aIdx !== bIdx) return aIdx - bIdx;
        return a.verse - b.verse;
      });

      const currentIdx = globalChapterIndex(
        visiblePosition.bookName,
        visiblePosition.chapterNumber,
      );

      if (direction === 1) {
        const next = sorted.find((h) => {
          const hIdx = globalChapterIndex(h.book, h.chapter);
          return hIdx > currentIdx || (hIdx === currentIdx && h.verse > 0);
        });
        const target = next ?? sorted[0];
        navigateTo(target.book, target.chapter, target.verse, target.verse);
      } else {
        const prev = [...sorted].reverse().find((h) => {
          const hIdx = globalChapterIndex(h.book, h.chapter);
          return hIdx < currentIdx;
        });
        const target = prev ?? sorted[sorted.length - 1];
        navigateTo(target.book, target.chapter, target.verse, target.verse);
      }
    },
    [highlights, visiblePosition, navigateTo],
  );

  const toggleBookmark = useCallback(async () => {
    const book = visiblePosition.bookName;
    const chapter = visiblePosition.chapterNumber;

    const existing = bookmarks.find(
      (b) => b.book === book && b.chapter === chapter,
    );

    if (existing) {
      // Remove bookmark
      await fetch(`/api/bookmarks?id=${existing.id}`, { method: "DELETE" });
      setBookmarks((prev) => prev.filter((b) => b.id !== existing.id));
    } else {
      // Add bookmark
      const res = await fetch("/api/bookmarks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ book, chapter }),
      });
      if (res.ok) {
        const newBookmark = await res.json();
        setBookmarks((prev) => [...prev, newBookmark]);
      }
    }
  }, [visiblePosition, bookmarks]);

  const handleAddHighlight = useCallback(
    async (
      book: string,
      chapter: number,
      verse: number,
      startChar: number,
      endChar: number,
      color: HighlightColor,
    ) => {
      const res = await fetch("/api/highlights", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ book, chapter, verse, startChar, endChar, color }),
      });
      if (res.ok) {
        const newHighlight = await res.json();
        setHighlights((prev) => [...prev, newHighlight]);
      }
    },
    [],
  );

  const handleRemoveHighlight = useCallback(
    async (
      book: string,
      chapter: number,
      verse: number,
      startChar: number,
      endChar: number,
    ) => {
      const existing = highlights.find(
        (h) =>
          h.book === book &&
          h.chapter === chapter &&
          h.verse === verse &&
          h.startChar === startChar &&
          h.endChar === endChar,
      );
      if (!existing) return;

      await fetch(`/api/highlights?id=${existing.id}`, { method: "DELETE" });
      setHighlights((prev) => prev.filter((h) => h.id !== existing.id));
    },
    [highlights],
  );

  const handleClearHistory = useCallback(async () => {
    await fetch("/api/history", { method: "DELETE" });
    setHistoryEntries([]);
  }, []);

  // -------------------------------------------------------------------------
  // Keyboard shortcuts
  // -------------------------------------------------------------------------

  useKeyboardShortcuts({
    onSearch: () => setShowSearch(true),
    onTOC: () => setShowTOC(true),
    onToggleHistory: () => setShowHistory((h) => !h),
    onPrevChapter: () => navigateChapter(-1),
    onNextChapter: () => navigateChapter(1),
    onToggleBookmark: () => toggleBookmark(),
    onPrevBookmark: () => navigateToBookmark(-1),
    onNextBookmark: () => navigateToBookmark(1),
    onPrevHighlight: () => navigateToHighlight(-1),
    onNextHighlight: () => navigateToHighlight(1),
    onShowShortcuts: () => setShowShortcuts(true),
    onDismiss: () => {
      setShowSearch(false);
      setShowTOC(false);
      setShowShortcuts(false);
    },
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  if (loading || (!user && !loading)) {
    return (
      <div className="flex h-screen items-center justify-center bg-white">
        <div className="text-stone-400 text-sm">Loading...</div>
      </div>
    );
  }

  if (!dataLoaded) {
    return (
      <div className="flex h-screen items-center justify-center bg-white">
        <div className="text-stone-400 text-sm">Loading Bible...</div>
      </div>
    );
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  return (
    <div className="flex h-screen">
      <div className="flex-1 relative">
        <ReadingPane
          initialPosition={currentPosition}
          navigationId={navigationCounter}
          highlightVerseStart={highlightStart}
          highlightVerseEnd={highlightEnd}
          bookmarks={bookmarks}
          highlights={highlights}
          redLetterData={redLetterData}
          onPositionChanged={(pos) => setVisiblePosition(pos)}
          onAddHighlight={handleAddHighlight}
          onRemoveHighlight={handleRemoveHighlight}
        />
        <BibleScrubber
          currentPosition={visiblePosition}
          bookmarks={bookmarks}
          highlights={highlights}
          onNavigate={(pos) => navigateTo(pos.bookName, pos.chapterNumber)}
        />
      </div>
      <HistorySidebar
        open={showHistory}
        onClose={() => setShowHistory(false)}
        entries={historyEntries}
        onNavigate={(book, ch, vs, ve) => navigateTo(book, ch, vs, ve)}
        onClear={handleClearHistory}
      />
      <SearchOverlay
        open={showSearch}
        onClose={() => setShowSearch(false)}
        onNavigate={(book, ch, vs, ve) => navigateTo(book, ch, vs, ve)}
      />
      <TOCOverlay
        open={showTOC}
        onClose={() => setShowTOC(false)}
        onNavigate={(book, ch) => navigateTo(book, ch)}
      />
      <KeyboardShortcutsOverlay
        open={showShortcuts}
        onClose={() => setShowShortcuts(false)}
      />
    </div>
  );
}
