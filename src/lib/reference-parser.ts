import { findBook } from "./bible-store";
import type { BibleReference } from "./types";

const refPattern = /^(\d?\s?[A-Za-z]+(?:\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$/;

export function parseReference(input: string): BibleReference | null {
  const trimmed = input.trim();
  const match = trimmed.match(refPattern);
  if (!match) return null;

  const bookQuery = match[1].trim();
  const chapter = parseInt(match[2], 10);
  const verseStart = match[3] ? parseInt(match[3], 10) : null;
  const verseEnd = match[4] ? parseInt(match[4], 10) : null;

  const book = findBook(bookQuery);
  if (!book) return null;

  return { book, chapter, verseStart, verseEnd };
}
