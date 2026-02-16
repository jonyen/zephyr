import type { Verse } from "./types";
import { bookNames, loadBook, findBook as findBookName } from "./bible-store";

interface IndexEntry {
  book: string;
  chapter: number;
  verse: number;
}

export interface VerseResult {
  id: string;
  book: string;
  chapter: number;
  verse: number;
  text: string;
}

let searchIndex: Record<string, IndexEntry[]> | null = null;

async function getIndex(): Promise<Record<string, IndexEntry[]>> {
  if (searchIndex) return searchIndex;
  const data = await import("@/data/search_index.json");
  searchIndex = data.default ?? data;
  return searchIndex!;
}

export async function search(query: string, limit = 50): Promise<VerseResult[]> {
  const index = await getIndex();
  const trimmed = query.trim().toLowerCase();
  if (!trimmed) return [];

  // Scoped search: "BookName: keyword"
  let scope: string | null = null;
  let keywords: string[];
  const colonIdx = trimmed.indexOf(":");
  if (colonIdx > 0) {
    const potentialBook = trimmed.slice(0, colonIdx).trim();
    const found = findBookName(potentialBook);
    if (found) {
      scope = found;
      keywords = trimmed.slice(colonIdx + 1).trim().split(/\s+/).filter(Boolean);
    } else {
      keywords = trimmed.split(/\s+/).filter(Boolean);
    }
  } else {
    keywords = trimmed.split(/\s+/).filter(Boolean);
  }

  if (keywords.length === 0) return [];

  // AND logic: intersect results for each keyword
  let resultEntries: IndexEntry[] | null = null;
  for (const kw of keywords) {
    const entries = index[kw] ?? [];
    if (resultEntries === null) {
      resultEntries = entries;
    } else {
      const set = new Set(entries.map((e) => `${e.book}.${e.chapter}.${e.verse}`));
      resultEntries = resultEntries.filter((e) => set.has(`${e.book}.${e.chapter}.${e.verse}`));
    }
  }

  if (!resultEntries) return [];

  // Apply scope filter
  if (scope) {
    resultEntries = resultEntries.filter((e) => e.book === scope);
  }

  // Sort by Bible order
  const bookOrder = new Map(bookNames.map((n, i) => [n, i]));
  resultEntries.sort((a, b) => {
    const ba = bookOrder.get(a.book) ?? 0;
    const bb = bookOrder.get(b.book) ?? 0;
    if (ba !== bb) return ba - bb;
    if (a.chapter !== b.chapter) return a.chapter - b.chapter;
    return a.verse - b.verse;
  });

  // Limit and look up text
  const results: VerseResult[] = [];
  for (const entry of resultEntries.slice(0, limit)) {
    const book = await loadBook(entry.book);
    const chapter = book?.chapters.find((c) => c.number === entry.chapter);
    const verse = chapter?.verses.find((v) => v.number === entry.verse);
    if (verse) {
      results.push({
        id: `${entry.book}.${entry.chapter}.${entry.verse}`,
        book: entry.book,
        chapter: entry.chapter,
        verse: entry.verse,
        text: verse.text,
      });
    }
  }

  return results;
}
