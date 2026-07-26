export interface Verse { number: number; text: string }
export interface Chapter { number: number; verses: Verse[] }
export interface Book { name: string; chapters: Chapter[] }
export interface Position { book: string; chapter: number }   // book = display name, e.g. "1 Corinthians"
export type HighlightColor = 'yellow' | 'green' | 'blue' | 'pink' | 'purple'
export interface Highlight { book: string; chapter: number; verse: number; startChar: number; endChar: number; color: HighlightColor }
export interface Bookmark { book: string; chapter: number }
export interface HistoryEntry { book: string; chapter: number; timestamp: number }
export interface Prefs { theme: 'system'|'light'|'dark'|'sepia'|'black'; font: 'georgia'|'palatino'|'helvetica'; redLetter: boolean; bionic: boolean }
