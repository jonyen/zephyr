"use client";

import { useCallback, useEffect, useState } from "react";
import { bookNames, chapterCounts } from "@/lib/bible-store";

interface TOCOverlayProps {
  open: boolean;
  onClose: () => void;
  onNavigate: (book: string, chapter: number) => void;
}

const otBooks = bookNames.slice(0, 39);
const ntBooks = bookNames.slice(39);

export default function TOCOverlay({ open, onClose, onNavigate }: TOCOverlayProps) {
  const [selectedBook, setSelectedBook] = useState<string | null>(null);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    },
    [onClose],
  );

  useEffect(() => {
    if (open) {
      document.addEventListener("keydown", handleKeyDown);
      return () => document.removeEventListener("keydown", handleKeyDown);
    }
  }, [open, handleKeyDown]);

  // Reset selected book when overlay closes
  useEffect(() => {
    if (!open) setSelectedBook(null);
  }, [open]);

  if (!open) return null;

  const handleChapterClick = (book: string, chapter: number) => {
    onNavigate(book, chapter);
    onClose();
  };

  const chapters = selectedBook ? chapterCounts[selectedBook] ?? 0 : 0;

  return (
    <div
      className="fixed inset-0 bg-black/30 backdrop-blur-sm z-50 flex justify-center"
      onClick={onClose}
    >
      <div
        className="max-w-2xl w-full mx-auto mt-16 bg-white rounded-xl shadow-2xl max-h-[80vh] overflow-hidden flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex flex-1 min-h-0">
          {/* Left column: book list */}
          <div className="w-1/2 overflow-y-auto border-r border-stone-200 py-2">
            <BookSection
              title="Old Testament"
              books={otBooks}
              selectedBook={selectedBook}
              onSelect={setSelectedBook}
            />
            <BookSection
              title="New Testament"
              books={ntBooks}
              selectedBook={selectedBook}
              onSelect={setSelectedBook}
            />
          </div>

          {/* Right column: chapter grid */}
          <div className="w-1/2 overflow-y-auto p-4">
            {selectedBook ? (
              <>
                <h3 className="text-sm font-semibold text-stone-700 mb-3">
                  {selectedBook}
                </h3>
                <div className="grid grid-cols-6 gap-1">
                  {Array.from({ length: chapters }, (_, i) => i + 1).map(
                    (ch) => (
                      <button
                        key={ch}
                        onClick={() => handleChapterClick(selectedBook, ch)}
                        className="rounded px-1 py-1.5 text-sm text-stone-700 hover:bg-stone-100 cursor-pointer transition-colors"
                      >
                        {ch}
                      </button>
                    ),
                  )}
                </div>
              </>
            ) : (
              <p className="text-sm text-stone-400 mt-8 text-center">
                Select a book to see chapters
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function BookSection({
  title,
  books,
  selectedBook,
  onSelect,
}: {
  title: string;
  books: string[];
  selectedBook: string | null;
  onSelect: (book: string) => void;
}) {
  return (
    <div className="mb-2">
      <h4 className="text-xs uppercase text-stone-400 font-semibold px-3 py-1">
        {title}
      </h4>
      {books.map((book) => (
        <button
          key={book}
          onClick={() => onSelect(book)}
          onMouseEnter={() => onSelect(book)}
          className={`block w-full text-left px-3 py-1.5 text-sm cursor-pointer transition-colors ${
            selectedBook === book
              ? "bg-stone-100 font-medium"
              : "hover:bg-stone-100"
          }`}
        >
          {book}
        </button>
      ))}
    </div>
  );
}
