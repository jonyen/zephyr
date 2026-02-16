export interface Verse {
  number: number;
  text: string;
}

export interface Chapter {
  number: number;
  verses: Verse[];
}

export interface Book {
  name: string;
  chapters: Chapter[];
}

export interface ChapterPosition {
  bookName: string;
  chapterNumber: number;
}

export type HighlightColor = "yellow" | "green" | "blue" | "pink";

export interface Highlight {
  id: string;
  book: string;
  chapter: number;
  verse: number;
  startChar: number;
  endChar: number;
  color: HighlightColor;
  createdAt: string;
}

export interface Bookmark {
  id: string;
  book: string;
  chapter: number;
  createdAt: string;
}

export interface HistoryEntry {
  id: string;
  book: string;
  chapter: number;
  verseStart: number | null;
  verseEnd: number | null;
  visitedAt: string;
}

export interface BibleReference {
  book: string;
  chapter: number;
  verseStart: number | null;
  verseEnd: number | null;
}
