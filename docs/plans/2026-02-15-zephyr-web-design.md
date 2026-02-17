# Zephyr Web — React Port Design

## Goal

Feature-parity React web version of the Zephyr macOS Bible reader app.

## Stack

- **Frontend**: Next.js (App Router) + React + Tailwind CSS
- **Backend**: Next.js API routes + better-sqlite3 (via Prisma ORM)
- **Auth**: Email/password with JWT in httpOnly cookies
- **Deployment**: Separate repo (`zephyr-web`)

## Architecture

Single Next.js app handling both frontend and API routes.

```
zephyr-web/
├── src/
│   ├── app/
│   │   ├── page.tsx              # Main reader
│   │   ├── login/page.tsx        # Login/register
│   │   ├── api/
│   │   │   ├── auth/             # POST login, register, logout
│   │   │   ├── bookmarks/        # GET, POST, DELETE
│   │   │   ├── highlights/       # GET, POST, DELETE
│   │   │   ├── history/          # GET, POST, DELETE (clear)
│   │   │   └── prefs/            # GET, PUT (lastBook, lastChapter)
│   │   └── layout.tsx
│   ├── components/
│   │   ├── ReadingPane.tsx        # Infinite scroll chapter view
│   │   ├── ChapterView.tsx        # Single chapter with verses
│   │   ├── BibleScrubber.tsx      # Right-side navigation track
│   │   ├── SearchOverlay.tsx      # Cmd+F search
│   │   ├── TOCOverlay.tsx         # Table of contents
│   │   ├── HistorySidebar.tsx     # Navigation history panel
│   │   └── KeyboardShortcuts.tsx  # Shortcuts overlay
│   ├── lib/
│   │   ├── bible-store.ts        # Book loading, chapter indexing, abbreviations
│   │   ├── reference-parser.ts   # Parse "John 3:16" etc.
│   │   ├── search-service.ts     # Keyword search across verses
│   │   ├── red-letter.ts         # Red letter verse data
│   │   ├── db.ts                 # Prisma client
│   │   └── auth.ts               # JWT helpers, middleware
│   ├── hooks/
│   │   ├── useKeyboardShortcuts.ts
│   │   ├── useInfiniteScroll.ts
│   │   └── useAuth.ts
│   ├── contexts/
│   │   └── AuthContext.tsx
│   └── data/                     # 66 book JSON files + red_letter_verses.json
├── prisma/
│   └── schema.prisma
├── tailwind.config.ts
├── package.json
└── tsconfig.json
```

## Database Schema

```prisma
model User {
  id           String      @id @default(uuid())
  email        String      @unique
  passwordHash String
  createdAt    DateTime    @default(now())
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
  color     String   // yellow, green, blue, pink
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

## API Routes

All routes except auth require valid JWT in httpOnly cookie.

| Method | Route | Description |
|--------|-------|-------------|
| POST | /api/auth/register | Create account |
| POST | /api/auth/login | Login, set cookie |
| POST | /api/auth/logout | Clear cookie |
| GET | /api/bookmarks | List user bookmarks |
| POST | /api/bookmarks | Toggle bookmark (book, chapter) |
| GET | /api/highlights?book=&chapter= | Get highlights for chapter |
| POST | /api/highlights | Add highlight |
| DELETE | /api/highlights/:id | Remove highlight |
| GET | /api/history | List recent entries |
| POST | /api/history | Add entry |
| DELETE | /api/history | Clear all |
| GET | /api/prefs | Get last position |
| PUT | /api/prefs | Update last position |

## Component Mapping (macOS → Web)

| macOS | Web |
|-------|-----|
| SwiftUI ScrollView + LazyVStack | div with Intersection Observer |
| NSTextView (SelectableTextView) | Native text selection + custom context menu |
| NSPanel (scrubber labels) | React portal with absolute positioning |
| Canvas (scrubber track) | HTML canvas or SVG |
| AppStorage | localStorage + API sync |
| NSEvent key monitor | useEffect + keydown listener |
| NotificationCenter | React context + callbacks / custom hooks |
| .inspector (history) | Sidebar div with slide transition |
| .regularMaterial | backdrop-blur + semi-transparent bg |

## Keyboard Shortcuts

Same as macOS app:

| Action | Shortcut |
|--------|----------|
| Search | Cmd+F |
| Table of Contents | Cmd+T |
| Toggle History | Cmd+Y |
| Previous Chapter | Cmd+[ |
| Next Chapter | Cmd+] |
| Toggle Bookmark | Cmd+B |
| Previous Bookmark | Cmd+Shift+Left |
| Next Bookmark | Cmd+Shift+Right |
| Previous Highlight | Cmd+{ |
| Next Highlight | Cmd+} |
| Page Up | Fn+Up |
| Page Down | Fn+Down |
| Show Shortcuts | ? |
| Dismiss | Esc |

Note: Cmd shortcuts will need Ctrl fallback for non-Mac users.

## Key Implementation Details

**Infinite Scroll**: Load initial chapter, observe first/last chapter elements with IntersectionObserver. Prepend/append chapters as they enter the viewport. Use `scrollIntoView` for navigation jumps.

**Text Highlighting**: Render verses as spans with data attributes. On text selection, calculate verse + character offsets from Selection API ranges. Context menu offers highlight colors and remove. Highlights rendered as background-color spans.

**Red Letter**: Load red_letter_verses.json. For matching verses, wrap quoted speech in red-colored spans.

**Search**: Reference parser runs client-side. Keyword search loads the search index JSON and filters client-side (same as macOS app). Debounced with 300ms delay.

**Bible Scrubber**: Canvas element for the track, ticks, diamonds, and thumb. Mouse events for drag navigation. Floating labels panel positioned with JS calculations matching the macOS fish-eye algorithm.

**Auth Flow**: Register/login pages. JWT with 7-day expiry. Middleware on API routes verifies token. On first load, fetch prefs to restore last position, then fetch bookmarks/highlights.
