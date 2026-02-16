import type { Book, ChapterPosition } from "./types";

export const bookNames: string[] = [
  "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
  "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
  "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
  "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Proverbs",
  "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
  "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
  "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
  "Haggai", "Zechariah", "Malachi",
  "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
  "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
  "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
  "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
  "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
  "Jude", "Revelation",
];

export const chapterCounts: Record<string, number> = {
  Genesis: 50, Exodus: 40, Leviticus: 27, Numbers: 36, Deuteronomy: 34,
  Joshua: 24, Judges: 21, Ruth: 4, "1 Samuel": 31, "2 Samuel": 24,
  "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36,
  Ezra: 10, Nehemiah: 13, Esther: 10, Job: 42, Psalm: 150, Proverbs: 31,
  Ecclesiastes: 12, "Song of Solomon": 8, Isaiah: 66, Jeremiah: 52,
  Lamentations: 5, Ezekiel: 48, Daniel: 12, Hosea: 14, Joel: 3, Amos: 9,
  Obadiah: 1, Jonah: 4, Micah: 7, Nahum: 3, Habakkuk: 3, Zephaniah: 3,
  Haggai: 2, Zechariah: 14, Malachi: 4,
  Matthew: 28, Mark: 16, Luke: 24, John: 21, Acts: 28, Romans: 16,
  "1 Corinthians": 16, "2 Corinthians": 13, Galatians: 6, Ephesians: 6,
  Philippians: 4, Colossians: 4, "1 Thessalonians": 5, "2 Thessalonians": 3,
  "1 Timothy": 6, "2 Timothy": 4, Titus: 3, Philemon: 1, Hebrews: 13,
  James: 5, "1 Peter": 5, "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1,
  Jude: 1, Revelation: 22,
};

const fileNameMap: Record<string, string> = {
  "1Samuel": "1 Samuel", "2Samuel": "2 Samuel",
  "1Kings": "1 Kings", "2Kings": "2 Kings",
  "1Chronicles": "1 Chronicles", "2Chronicles": "2 Chronicles",
  "SongOfSolomon": "Song of Solomon",
  "1Corinthians": "1 Corinthians", "2Corinthians": "2 Corinthians",
  "1Thessalonians": "1 Thessalonians", "2Thessalonians": "2 Thessalonians",
  "1Timothy": "1 Timothy", "2Timothy": "2 Timothy",
  "1Peter": "1 Peter", "2Peter": "2 Peter",
  "1John": "1 John", "2John": "2 John", "3John": "3 John",
};

const displayToFileName: Record<string, string> = {};
for (const [file, display] of Object.entries(fileNameMap)) {
  displayToFileName[display] = file;
}

export const totalChapters = bookNames.reduce((sum, name) => sum + (chapterCounts[name] ?? 0), 0);

const bookCache: Map<string, Book> = new Map();

export async function loadBook(name: string): Promise<Book | null> {
  if (bookCache.has(name)) return bookCache.get(name)!;
  const fileName = displayToFileName[name] || name.replace(/\s/g, "");
  try {
    const data = await import(`@/data/${fileName}.json`);
    const book: Book = { name, chapters: data.chapters ?? data.default?.chapters };
    bookCache.set(name, book);
    return book;
  } catch {
    return null;
  }
}

export function globalChapterIndex(book: string, chapter: number): number {
  let index = 0;
  for (const name of bookNames) {
    if (name === book) return index + chapter - 1;
    index += chapterCounts[name] ?? 0;
  }
  return index;
}

export function chapterPosition(globalIndex: number): ChapterPosition {
  const clamped = Math.max(0, Math.min(globalIndex, totalChapters - 1));
  let index = 0;
  for (const name of bookNames) {
    const count = chapterCounts[name] ?? 0;
    if (clamped < index + count) {
      return { bookName: name, chapterNumber: clamped - index + 1 };
    }
    index += count;
  }
  const last = bookNames[bookNames.length - 1];
  return { bookName: last, chapterNumber: chapterCounts[last] ?? 1 };
}

const abbreviationMap: Record<string, string> = {
  gen: "Genesis", ex: "Exodus", exod: "Exodus", lev: "Leviticus",
  num: "Numbers", deut: "Deuteronomy", josh: "Joshua", judg: "Judges",
  "1sam": "1 Samuel", "2sam": "2 Samuel", "1kgs": "1 Kings", "2kgs": "2 Kings",
  "1chr": "1 Chronicles", "2chr": "2 Chronicles", neh: "Nehemiah",
  est: "Esther", ps: "Psalm", psa: "Psalm", psalm: "Psalm", prov: "Proverbs",
  eccl: "Ecclesiastes", song: "Song of Solomon", isa: "Isaiah",
  jer: "Jeremiah", lam: "Lamentations", ezek: "Ezekiel", dan: "Daniel",
  hos: "Hosea", ob: "Obadiah", mic: "Micah", nah: "Nahum",
  hab: "Habakkuk", zeph: "Zephaniah", hag: "Haggai", zech: "Zechariah",
  mal: "Malachi", matt: "Matthew", mk: "Mark", lk: "Luke", jn: "John",
  rom: "Romans", "1cor": "1 Corinthians", "2cor": "2 Corinthians",
  gal: "Galatians", eph: "Ephesians", phil: "Philippians", col: "Colossians",
  "1thess": "1 Thessalonians", "2thess": "2 Thessalonians",
  "1tim": "1 Timothy", "2tim": "2 Timothy", tit: "Titus",
  phlm: "Philemon", heb: "Hebrews", jas: "James", "1pet": "1 Peter",
  "2pet": "2 Peter", "1jn": "1 John", "2jn": "2 John", "3jn": "3 John",
  rev: "Revelation",
};

export function findBook(query: string): string | null {
  const q = query.trim();
  const exact = bookNames.find((n) => n.toLowerCase() === q.toLowerCase());
  if (exact) return exact;
  const abbr = abbreviationMap[q.toLowerCase()];
  if (abbr) return abbr;
  const prefix = bookNames.find((n) => n.toLowerCase().startsWith(q.toLowerCase()));
  return prefix ?? null;
}
