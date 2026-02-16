"use client";

import type { HistoryEntry } from "@/lib/types";

interface HistorySidebarProps {
  open: boolean;
  onClose: () => void;
  entries: HistoryEntry[];
  onNavigate: (
    book: string,
    chapter: number,
    verseStart: number | null,
    verseEnd: number | null,
  ) => void;
  onClear: () => void;
}

function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHr = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHr / 24);

  if (diffSec < 60) return "just now";
  if (diffMin < 60) return `${diffMin} min ago`;
  if (diffHr < 24) return `${diffHr}h ago`;
  if (diffDay < 7) return `${diffDay}d ago`;

  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
}

function formatEntryLabel(entry: HistoryEntry): string {
  let label = `${entry.book} ${entry.chapter}`;
  if (entry.verseStart !== null) {
    label += `:${entry.verseStart}`;
    if (entry.verseEnd !== null && entry.verseEnd !== entry.verseStart) {
      label += `-${entry.verseEnd}`;
    }
  }
  return label;
}

export default function HistorySidebar({
  open,
  onClose,
  entries,
  onNavigate,
  onClear,
}: HistorySidebarProps) {
  return (
    <div
      className={`fixed right-0 top-0 h-full w-[280px] z-40 bg-white/80 backdrop-blur-xl shadow-2xl flex flex-col transition-transform duration-300 ease-in-out ${
        open ? "translate-x-0" : "translate-x-full"
      }`}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-stone-200">
        <h2 className="text-sm font-semibold text-stone-800">History</h2>
        <button
          onClick={onClose}
          className="text-stone-400 hover:text-stone-700 transition-colors"
          aria-label="Close history"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-5 w-5"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fillRule="evenodd"
              d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
              clipRule="evenodd"
            />
          </svg>
        </button>
      </div>

      {/* Entry list */}
      <div className="flex-1 overflow-y-auto">
        {entries.length === 0 ? (
          <p className="px-4 py-8 text-sm text-stone-400 text-center">
            No history yet
          </p>
        ) : (
          entries.map((entry) => (
            <button
              key={entry.id}
              onClick={() => {
                onNavigate(
                  entry.book,
                  entry.chapter,
                  entry.verseStart,
                  entry.verseEnd,
                );
                onClose();
              }}
              className="w-full text-left px-4 py-2 hover:bg-stone-100 cursor-pointer transition-colors"
            >
              <span className="text-sm text-stone-800">
                {formatEntryLabel(entry)}
              </span>
              <span className="block text-xs text-stone-400 mt-0.5">
                {formatRelativeTime(entry.visitedAt)}
              </span>
            </button>
          ))
        )}
      </div>

      {/* Clear button */}
      {entries.length > 0 && (
        <div className="border-t border-stone-200 px-4 py-3">
          <button
            onClick={onClear}
            className="w-full text-sm text-red-500 hover:text-red-700 transition-colors"
          >
            Clear History
          </button>
        </div>
      )}
    </div>
  );
}
