# Zephyr Web Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a feature-parity React web version of the Zephyr macOS Bible reader app.

**Architecture:** Next.js App Router monolith with API routes for auth and user data. SQLite via Prisma for persistence. Bible text served from static JSON files. All keyboard shortcuts, infinite scroll, highlights, bookmarks, search, and scrubber ported from macOS.

**Tech Stack:** Next.js 15, React 19, Tailwind CSS 4, Prisma + SQLite, bcryptjs, jose (JWT), TypeScript

---

### Task 1: Project Scaffold

**Files:**
- Create: `zephyr-web/package.json`
- Create: `zephyr-web/tsconfig.json`
- Create: `zephyr-web/tailwind.config.ts`
- Create: `zephyr-web/src/app/layout.tsx`
- Create: `zephyr-web/src/app/page.tsx`
- Create: `zephyr-web/prisma/schema.prisma`

**Step 1: Create repo and init Next.js**

```bash
cd /Users/jonyen/Projects
npx create-next-app@latest zephyr-web --typescript --tailwind --eslint --app --src-dir --no-import-alias
cd zephyr-web
```

**Step 2: Install dependencies**

```bash
npm install prisma @prisma/client bcryptjs jose
npm install -D @types/bcryptjs
```

**Step 3: Init Prisma with SQLite**

```bash
npx prisma init --datasource-provider sqlite
```

**Step 4: Write Prisma schema**

Replace `prisma/schema.prisma` with:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

model User {
  id           String         @id @default(uuid())
  email        String         @unique
  passwordHash String
  createdAt    DateTime       @default(now())
  bookmarks    Bookmark[]
  highlights   Highlight[]
  history      HistoryEntry[]
  prefs        UserPrefs?
}

model Bookmark {
  id        String   @id @default(uuid())
  userId    String
  book      String
  chapter   Int
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id])

  @@unique([userId, book, chapter])
}

model Highlight {
  id        String   @id @default(uuid())
  userId    String
  book      String
  chapter   Int
  verse     Int
  startChar Int
  endChar   Int
  color     String
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id])
}

model HistoryEntry {
  id         String   @id @default(uuid())
  userId     String
  book       String
  chapter    Int
  verseStart Int?
  verseEnd   Int?
  visitedAt  DateTime @default(now())
  user       User     @relation(fields: [userId], references: [id])
}

model UserPrefs {
  userId      String @id
  lastBook    String @default("Genesis")
  lastChapter Int    @default(1)
  user        User   @relation(fields: [userId], references: [id])
}
```

**Step 5: Run migration**

```bash
npx prisma migrate dev --name init
```

**Step 6: Copy Bible data files**

```bash
mkdir -p src/data
cp /Users/jonyen/Projects/zephyr/ESVBible/Resources/*.json src/data/
rm src/data/search_index.json  # will copy separately if needed
cp /Users/jonyen/Projects/zephyr/ESVBible/Resources/search_index.json src/data/
cp /Users/jonyen/Projects/zephyr/ESVBible/Resources/red_letter_verses.json src/data/
```

**Step 7: Verify dev server starts**

```bash
npm run dev
```

**Step 8: Commit**

```bash
git add -A && git commit -m "feat: scaffold Next.js project with Prisma SQLite schema and Bible data"
```

---

### Task 2: Bible Store & Types

**Files:**
- Create: `src/lib/types.ts`
- Create: `src/lib/bible-store.ts`

**Step 1: Create types**

```typescript
// src/lib/types.ts
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
```

**Step 2: Create bible-store**

Port the Swift BibleStore to TypeScript. Include bookNames, chapterCounts, globalChapterIndex, chapterPosition, abbreviations, and findBook.

```typescript
// src/lib/bible-store.ts
import type { Book, Chapter, ChapterPosition } from "./types";

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

// Map from JSON filename to display name (JSON files use no-space names)
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
  // Exact match
  const exact = bookNames.find((n) => n.toLowerCase() === q.toLowerCase());
  if (exact) return exact;
  // Abbreviation
  const abbr = abbreviationMap[q.toLowerCase()];
  if (abbr) return abbr;
  // Prefix match
  const prefix = bookNames.find((n) => n.toLowerCase().startsWith(q.toLowerCase()));
  return prefix ?? null;
}
```

**Step 3: Verify it compiles**

```bash
npx tsc --noEmit
```

**Step 4: Commit**

```bash
git add src/lib/types.ts src/lib/bible-store.ts && git commit -m "feat: add Bible store with types, book data, and chapter indexing"
```

---

### Task 3: Reference Parser & Search Service

**Files:**
- Create: `src/lib/reference-parser.ts`
- Create: `src/lib/search-service.ts`
- Create: `src/lib/red-letter.ts`

**Step 1: Create reference parser**

```typescript
// src/lib/reference-parser.ts
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
```

**Step 2: Create search service**

```typescript
// src/lib/search-service.ts
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
```

**Step 3: Create red letter service**

```typescript
// src/lib/red-letter.ts
let redLetterData: Record<string, Record<string, number[]>> | null = null;

async function getData(): Promise<Record<string, Record<string, number[]>>> {
  if (redLetterData) return redLetterData;
  const data = await import("@/data/red_letter_verses.json");
  redLetterData = data.default ?? data;
  return redLetterData!;
}

export async function isRedLetter(book: string, chapter: number, verse: number): Promise<boolean> {
  const data = await getData();
  const chapters = data[book];
  if (!chapters) return false;
  const verses = chapters[String(chapter)];
  if (!verses) return false;
  return verses.includes(verse);
}
```

**Step 4: Verify**

```bash
npx tsc --noEmit
```

**Step 5: Commit**

```bash
git add src/lib/ && git commit -m "feat: add reference parser, search service, and red letter service"
```

---

### Task 4: Auth Backend (JWT + API Routes)

**Files:**
- Create: `src/lib/db.ts`
- Create: `src/lib/auth.ts`
- Create: `src/app/api/auth/register/route.ts`
- Create: `src/app/api/auth/login/route.ts`
- Create: `src/app/api/auth/logout/route.ts`

**Step 1: Create Prisma client singleton**

```typescript
// src/lib/db.ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };
export const prisma = globalForPrisma.prisma || new PrismaClient();
if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

**Step 2: Create auth helpers**

```typescript
// src/lib/auth.ts
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

const secret = new TextEncoder().encode(process.env.JWT_SECRET || "dev-secret-change-in-production");

export async function createToken(userId: string): Promise<string> {
  return new SignJWT({ userId })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime("7d")
    .sign(secret);
}

export async function verifyToken(token: string): Promise<{ userId: string } | null> {
  try {
    const { payload } = await jwtVerify(token, secret);
    return { userId: payload.userId as string };
  } catch {
    return null;
  }
}

export async function getAuthUser(): Promise<string | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get("token")?.value;
  if (!token) return null;
  const result = await verifyToken(token);
  return result?.userId ?? null;
}
```

**Step 3: Create auth API routes**

```typescript
// src/app/api/auth/register/route.ts
import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/db";
import { createToken } from "@/lib/auth";

export async function POST(req: Request) {
  const { email, password } = await req.json();
  if (!email || !password || password.length < 6) {
    return NextResponse.json({ error: "Email and password (min 6 chars) required" }, { status: 400 });
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return NextResponse.json({ error: "Email already registered" }, { status: 409 });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({ data: { email, passwordHash } });
  await prisma.userPrefs.create({ data: { userId: user.id } });

  const token = await createToken(user.id);
  const response = NextResponse.json({ id: user.id, email: user.email });
  response.cookies.set("token", token, {
    httpOnly: true, secure: process.env.NODE_ENV === "production",
    sameSite: "lax", maxAge: 60 * 60 * 24 * 7, path: "/",
  });
  return response;
}
```

```typescript
// src/app/api/auth/login/route.ts
import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/db";
import { createToken } from "@/lib/auth";

export async function POST(req: Request) {
  const { email, password } = await req.json();
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
  }

  const token = await createToken(user.id);
  const response = NextResponse.json({ id: user.id, email: user.email });
  response.cookies.set("token", token, {
    httpOnly: true, secure: process.env.NODE_ENV === "production",
    sameSite: "lax", maxAge: 60 * 60 * 24 * 7, path: "/",
  });
  return response;
}
```

```typescript
// src/app/api/auth/logout/route.ts
import { NextResponse } from "next/server";

export async function POST() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set("token", "", { httpOnly: true, maxAge: 0, path: "/" });
  return response;
}
```

**Step 4: Add .env**

```bash
echo 'JWT_SECRET=change-me-to-a-random-secret' > .env
echo '.env' >> .gitignore
```

**Step 5: Verify**

```bash
npx tsc --noEmit
```

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: add auth backend with JWT, register, login, logout"
```

---

### Task 5: User Data API Routes (Bookmarks, Highlights, History, Prefs)

**Files:**
- Create: `src/app/api/bookmarks/route.ts`
- Create: `src/app/api/highlights/route.ts`
- Create: `src/app/api/highlights/[id]/route.ts`
- Create: `src/app/api/history/route.ts`
- Create: `src/app/api/prefs/route.ts`

**Step 1: Bookmarks API**

```typescript
// src/app/api/bookmarks/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const bookmarks = await prisma.bookmark.findMany({ where: { userId }, orderBy: { createdAt: "desc" } });
  return NextResponse.json(bookmarks);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter } = await req.json();
  const existing = await prisma.bookmark.findUnique({ where: { userId_book_chapter: { userId, book, chapter } } });
  if (existing) {
    await prisma.bookmark.delete({ where: { id: existing.id } });
    return NextResponse.json({ removed: true });
  }
  const bookmark = await prisma.bookmark.create({ data: { userId, book, chapter } });
  return NextResponse.json(bookmark);
}
```

**Step 2: Highlights API**

```typescript
// src/app/api/highlights/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { searchParams } = new URL(req.url);
  const book = searchParams.get("book");
  const chapter = searchParams.get("chapter");
  const where: Record<string, unknown> = { userId };
  if (book) where.book = book;
  if (chapter) where.chapter = parseInt(chapter, 10);
  const highlights = await prisma.highlight.findMany({ where, orderBy: { createdAt: "desc" } });
  return NextResponse.json(highlights);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter, verse, startChar, endChar, color } = await req.json();
  const highlight = await prisma.highlight.create({ data: { userId, book, chapter, verse, startChar, endChar, color } });
  return NextResponse.json(highlight);
}
```

```typescript
// src/app/api/highlights/[id]/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function DELETE(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { id } = await params;
  const highlight = await prisma.highlight.findUnique({ where: { id } });
  if (!highlight || highlight.userId !== userId) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  await prisma.highlight.delete({ where: { id } });
  return NextResponse.json({ ok: true });
}
```

**Step 3: History API**

```typescript
// src/app/api/history/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const entries = await prisma.historyEntry.findMany({
    where: { userId }, orderBy: { visitedAt: "desc" }, take: 100,
  });
  return NextResponse.json(entries);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter, verseStart, verseEnd } = await req.json();
  const entry = await prisma.historyEntry.create({
    data: { userId, book, chapter, verseStart: verseStart ?? null, verseEnd: verseEnd ?? null },
  });
  return NextResponse.json(entry);
}

export async function DELETE() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await prisma.historyEntry.deleteMany({ where: { userId } });
  return NextResponse.json({ ok: true });
}
```

**Step 4: Prefs API**

```typescript
// src/app/api/prefs/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const prefs = await prisma.userPrefs.findUnique({ where: { userId } });
  return NextResponse.json(prefs ?? { lastBook: "Genesis", lastChapter: 1 });
}

export async function PUT(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { lastBook, lastChapter } = await req.json();
  const prefs = await prisma.userPrefs.upsert({
    where: { userId },
    update: { lastBook, lastChapter },
    create: { userId, lastBook, lastChapter },
  });
  return NextResponse.json(prefs);
}
```

**Step 5: Verify and commit**

```bash
npx tsc --noEmit
git add -A && git commit -m "feat: add API routes for bookmarks, highlights, history, and prefs"
```

---

### Task 6: Auth Context & Login Page

**Files:**
- Create: `src/contexts/AuthContext.tsx`
- Create: `src/hooks/useAuth.ts`
- Create: `src/app/login/page.tsx`
- Modify: `src/app/layout.tsx`

**Step 1: Create auth context**

```typescript
// src/contexts/AuthContext.tsx
"use client";
import { createContext, useContext, useState, useEffect, type ReactNode } from "react";

interface AuthUser { id: string; email: string }
interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/auth/me").then((r) => r.ok ? r.json() : null).then(setUser).finally(() => setLoading(false));
  }, []);

  const login = async (email: string, password: string) => {
    const res = await fetch("/api/auth/login", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!res.ok) throw new Error((await res.json()).error);
    setUser(await res.json());
  };

  const register = async (email: string, password: string) => {
    const res = await fetch("/api/auth/register", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!res.ok) throw new Error((await res.json()).error);
    setUser(await res.json());
  };

  const logout = async () => {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
```

Note: also create `/api/auth/me/route.ts`:

```typescript
// src/app/api/auth/me/route.ts
import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json(null, { status: 401 });
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { id: true, email: true } });
  return NextResponse.json(user);
}
```

**Step 2: Create login page**

```typescript
// src/app/login/page.tsx
"use client";
import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const { login, register } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      if (isRegister) await register(email, password);
      else await login(email, password);
      router.push("/");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "An error occurred");
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-stone-50">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4 rounded-xl bg-white p-8 shadow-lg">
        <h1 className="text-2xl font-bold text-center">Zephyr</h1>
        <p className="text-center text-stone-500 text-sm">{isRegister ? "Create account" : "Sign in"}</p>
        {error && <p className="text-red-500 text-sm text-center">{error}</p>}
        <input type="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-lg border px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500" required />
        <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)}
          className="w-full rounded-lg border px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500" required minLength={6} />
        <button type="submit" className="w-full rounded-lg bg-blue-600 py-2 text-white font-medium hover:bg-blue-700">
          {isRegister ? "Register" : "Sign In"}
        </button>
        <button type="button" onClick={() => setIsRegister(!isRegister)} className="w-full text-sm text-blue-600">
          {isRegister ? "Already have an account? Sign in" : "Need an account? Register"}
        </button>
      </form>
    </div>
  );
}
```

**Step 3: Wrap layout with AuthProvider**

Update `src/app/layout.tsx` to wrap children in `<AuthProvider>`.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add auth context, login page, and /api/auth/me route"
```

---

### Task 7: ChapterView Component

**Files:**
- Create: `src/components/ChapterView.tsx`

Renders a single chapter with verse numbers (superscript), red letter text, user highlights, bookmark icon, and right-click context menu for highlight actions. Uses native text selection + Selection API for character offset calculation.

**Step 1: Build component**

Create `src/components/ChapterView.tsx` with:
- Props: `chapter`, `bookName`, `highlights`, `bookmarked`, `redLetterVerses`, `highlightVerseStart?`, `highlightVerseEnd?`, `onAddHighlight`, `onRemoveHighlight`
- Render each verse as a `<span data-verse={n}>` with superscript number
- Apply highlight background colors inline
- Red letter: wrap text after opening `\u201C` in red
- Context menu (right-click) on text selection: detect verse + char offsets via Selection API, offer 4 highlight colors + remove

**Step 2: Commit**

```bash
git add src/components/ChapterView.tsx && git commit -m "feat: add ChapterView with highlights, red letter, and context menu"
```

---

### Task 8: ReadingPane with Infinite Scroll

**Files:**
- Create: `src/components/ReadingPane.tsx`
- Create: `src/hooks/useInfiniteScroll.ts`

**Step 1: Build infinite scroll hook**

Uses IntersectionObserver on sentinel elements at the top and bottom of the loaded chapter list. Prepends/appends chapters as they come into view.

**Step 2: Build ReadingPane**

- Loads initial chapter, renders ChapterView for each loaded chapter
- Scrolls to target chapter on navigation (via `scrollIntoView`)
- Reports visible position changes to parent via callback
- Fetches highlights and bookmark status per chapter from API

**Step 3: Commit**

```bash
git add src/components/ src/hooks/ && git commit -m "feat: add ReadingPane with infinite scroll"
```

---

### Task 9: Search Overlay

**Files:**
- Create: `src/components/SearchOverlay.tsx`

Floating overlay triggered by Cmd+F. Text input with debounced keyword search (300ms). Reference parsing on submit. Results list with click-to-navigate. Dismiss on Escape or click outside.

**Step 1: Build component, commit**

```bash
git add src/components/SearchOverlay.tsx && git commit -m "feat: add search overlay with reference parsing and keyword search"
```

---

### Task 10: Table of Contents Overlay

**Files:**
- Create: `src/components/TOCOverlay.tsx`

Modal with book list (OT/NT sections) on left, chapter grid on hover/click on right. Dismiss on Escape or backdrop click.

**Step 1: Build component, commit**

```bash
git add src/components/TOCOverlay.tsx && git commit -m "feat: add table of contents overlay"
```

---

### Task 11: History Sidebar

**Files:**
- Create: `src/components/HistorySidebar.tsx`

Right-side slide-in panel. Lists recent visits from API. Click to navigate. Clear button.

**Step 1: Build component, commit**

```bash
git add src/components/HistorySidebar.tsx && git commit -m "feat: add history sidebar"
```

---

### Task 12: Bible Scrubber

**Files:**
- Create: `src/components/BibleScrubber.tsx`

Right-side fixed track using `<canvas>`. Draws track line, highlight ticks, bookmark diamonds, thumb. Mouse drag for scrub navigation. On hover, show floating label panel (absolutely positioned div) with all 66 book names using fish-eye scaling algorithm from macOS app.

**Step 1: Build component, commit**

```bash
git add src/components/BibleScrubber.tsx && git commit -m "feat: add Bible scrubber with canvas track and floating labels"
```

---

### Task 13: Keyboard Shortcuts

**Files:**
- Create: `src/hooks/useKeyboardShortcuts.ts`
- Create: `src/components/KeyboardShortcutsOverlay.tsx`

**Step 1: Build keyboard hook**

`useEffect` with `keydown` listener. Handles all shortcuts from the macOS app. Uses `e.metaKey || e.ctrlKey` for cross-platform Cmd/Ctrl support. Calls callbacks passed via props/context.

**Step 2: Build shortcuts overlay**

Modal listing all shortcuts. Triggered by `?` key. Styled to match macOS version.

**Step 3: Commit**

```bash
git add src/hooks/ src/components/KeyboardShortcutsOverlay.tsx && git commit -m "feat: add keyboard shortcuts with overlay"
```

---

### Task 14: Main Page — Wire Everything Together

**Files:**
- Modify: `src/app/page.tsx`
- Modify: `src/app/layout.tsx`

**Step 1: Build main page**

Wire all components together in `page.tsx`:
- Auth guard (redirect to /login if not authenticated)
- State: currentPosition, visiblePosition, navigationCounter, highlightStart/End, showSearch, showTOC, showHistory, showShortcuts
- Fetch bookmarks + highlights from API, pass to components
- Navigation functions: navigateTo, navigateChapter, navigateToBookmark, navigateToHighlight
- Keyboard shortcuts hook
- Save last position to API on navigate

**Step 2: Test full flow manually**

```bash
npm run dev
```

Register, navigate chapters, add bookmarks/highlights, search, verify keyboard shortcuts.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: wire up main reader page with all components"
```

---

### Task 15: Polish & Deploy Prep

**Files:**
- Modify: `src/app/globals.css` — serif font for reading, Tailwind refinements
- Create: `.env.example`
- Modify: `package.json` — add build/start scripts

**Step 1: Style polish**

Add Georgia/serif font for reading text, adjust spacing, ensure dark/light mode works with Tailwind.

**Step 2: Create .env.example**

```
JWT_SECRET=your-secret-here
DATABASE_URL=file:./prisma/dev.db
```

**Step 3: Verify production build**

```bash
npm run build && npm start
```

**Step 4: Final commit**

```bash
git add -A && git commit -m "feat: style polish and deploy prep"
```

---

Plan complete and saved to `docs/plans/2026-02-15-zephyr-web-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open a new session with executing-plans, batch execution with checkpoints

Which approach?