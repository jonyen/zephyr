"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { parseReference } from "@/lib/reference-parser";
import { search, type VerseResult } from "@/lib/search-service";

interface SearchOverlayProps {
  open: boolean;
  onClose: () => void;
  onNavigate: (
    book: string,
    chapter: number,
    verseStart: number | null,
    verseEnd: number | null,
  ) => void;
}

export default function SearchOverlay({
  open,
  onClose,
  onNavigate,
}: SearchOverlayProps) {
  const [query, setQuery] = useState("");
  const [referenceLabel, setReferenceLabel] = useState<string | null>(null);
  const [referenceResult, setReferenceResult] = useState<{
    book: string;
    chapter: number;
    verseStart: number | null;
    verseEnd: number | null;
  } | null>(null);
  const [keywordResults, setKeywordResults] = useState<VerseResult[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Auto-focus input when opened
  useEffect(() => {
    if (open) {
      setQuery("");
      setReferenceLabel(null);
      setReferenceResult(null);
      setKeywordResults([]);
      setSelectedIndex(0);
      // Small delay to ensure the DOM is ready
      const t = setTimeout(() => inputRef.current?.focus(), 50);
      return () => clearTimeout(t);
    }
  }, [open]);

  // Handle input changes: parse reference immediately, debounce keyword search
  const handleChange = useCallback(
    (value: string) => {
      setQuery(value);
      setSelectedIndex(0);

      // Synchronous reference parse
      const ref = parseReference(value);
      if (ref) {
        const label = formatReference(ref.book, ref.chapter, ref.verseStart, ref.verseEnd);
        setReferenceLabel(label);
        setReferenceResult(ref);
      } else {
        setReferenceLabel(null);
        setReferenceResult(null);
      }

      // Debounced keyword search
      if (debounceRef.current) clearTimeout(debounceRef.current);
      const trimmed = value.trim();
      if (!trimmed) {
        setKeywordResults([]);
        return;
      }
      debounceRef.current = setTimeout(async () => {
        try {
          const results = await search(trimmed);
          setKeywordResults(results);
        } catch {
          setKeywordResults([]);
        }
      }, 300);
    },
    [],
  );

  // Cleanup debounce on unmount
  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  const totalResults = (referenceResult ? 1 : 0) + keywordResults.length;

  const selectResult = useCallback(
    (index: number) => {
      if (referenceResult && index === 0) {
        onNavigate(
          referenceResult.book,
          referenceResult.chapter,
          referenceResult.verseStart,
          referenceResult.verseEnd,
        );
        onClose();
        return;
      }
      const kwIndex = referenceResult ? index - 1 : index;
      const result = keywordResults[kwIndex];
      if (result) {
        onNavigate(result.book, result.chapter, result.verse, null);
        onClose();
      }
    },
    [referenceResult, keywordResults, onNavigate, onClose],
  );

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
        return;
      }
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex((prev) => Math.min(prev + 1, totalResults - 1));
        return;
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex((prev) => Math.max(prev - 1, 0));
        return;
      }
      if (e.key === "Enter") {
        e.preventDefault();
        if (totalResults > 0) {
          selectResult(selectedIndex);
        }
      }
    },
    [onClose, totalResults, selectedIndex, selectResult],
  );

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 bg-black/30 backdrop-blur-sm z-50"
      onClick={onClose}
    >
      <div
        className="max-w-lg mx-auto mt-24 bg-white rounded-xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Search input */}
        <div className="flex items-center border-b border-stone-200">
          <svg
            className="ml-4 h-5 w-5 text-stone-400 shrink-0"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-4.35-4.35M11 19a8 8 0 100-16 8 8 0 000 16z"
            />
          </svg>
          <input
            ref={inputRef}
            type="text"
            className="w-full px-4 py-3 text-lg bg-transparent focus:outline-none"
            placeholder="Type a reference (John 3:16) or keyword"
            value={query}
            onChange={(e) => handleChange(e.target.value)}
            onKeyDown={handleKeyDown}
          />
        </div>

        {/* Results list */}
        {totalResults > 0 && (
          <ul className="max-h-80 overflow-y-auto divide-y divide-stone-100">
            {/* Reference match */}
            {referenceResult && referenceLabel && (
              <li
                className={`px-4 py-2 cursor-pointer ${
                  selectedIndex === 0
                    ? "bg-blue-50"
                    : "hover:bg-stone-50"
                }`}
                onClick={() => selectResult(0)}
              >
                <span className="font-semibold text-blue-700">
                  Go to {referenceLabel}
                </span>
              </li>
            )}

            {/* Keyword results */}
            {keywordResults.map((result, i) => {
              const resultIndex = referenceResult ? i + 1 : i;
              return (
                <li
                  key={result.id}
                  className={`px-4 py-2 cursor-pointer ${
                    selectedIndex === resultIndex
                      ? "bg-blue-50"
                      : "hover:bg-stone-50"
                  }`}
                  onClick={() => selectResult(resultIndex)}
                >
                  <span className="font-medium text-stone-800">
                    {result.book} {result.chapter}:{result.verse}
                  </span>
                  <span className="text-stone-400 mx-1">&mdash;</span>
                  <span className="text-stone-600 text-sm">
                    {truncate(result.text, 100)}
                  </span>
                </li>
              );
            })}
          </ul>
        )}

        {/* Hint text when no results and no query */}
        {!query.trim() && (
          <p className="px-4 py-3 text-sm text-stone-400">
            Type a reference (John 3:16) or keyword to search
          </p>
        )}
      </div>
    </div>
  );
}

function formatReference(
  book: string,
  chapter: number,
  verseStart: number | null,
  verseEnd: number | null,
): string {
  let label = `${book} ${chapter}`;
  if (verseStart != null) {
    label += `:${verseStart}`;
    if (verseEnd != null) {
      label += `-${verseEnd}`;
    }
  }
  return label;
}

function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength).trimEnd() + "\u2026";
}
