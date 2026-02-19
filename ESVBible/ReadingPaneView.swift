import SwiftUI

// Uniquely identifies a rendered chapter in the scroll view.
private struct ChapterID: Hashable {
    let bookName: String
    let chapterNumber: Int
}

private struct VerseAnchorID: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verse: Int
}


struct ReadingPaneView: View {
    let initialPosition: ChapterPosition
    let navigationID: Int
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?
    let bibleStore: BibleStore
    let highlightManager: HighlightManager
    /// Called whenever the topmost visible chapter changes.
    var onPositionChanged: ((ChapterPosition) -> Void)?
    /// Called when the scrubber requests navigation to a chapter.
    var onNavigateRequested: ((ChapterPosition) -> Void)?

    // The ordered list of chapters currently in the scroll view.
    @State private var loadedChapters: [ChapterPosition] = []
    @State private var scrolledID: ChapterID?
    @State private var visiblePosition: ChapterPosition?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(loadedChapters, id: \.self) { position in
                        if let book = bibleStore.findBook(position.bookName),
                           let chapter = book.chapters.first(where: { $0.number == position.chapterNumber }) {
                            ChapterView(
                                chapter: chapter,
                                bookName: book.name,
                                isFirstChapter: chapter.number == 1,
                                highlightVerseStart: position == initialPosition ? highlightVerseStart : nil,
                                highlightVerseEnd: position == initialPosition ? highlightVerseEnd : nil,
                                highlightManager: highlightManager,
                                notes: highlightManager.notes(forBook: book.name, chapter: chapter.number)
                            )
                            .id(ChapterID(bookName: position.bookName, chapterNumber: position.chapterNumber))
                            .onAppear {
                                if position == loadedChapters.first {
                                    prependPreviousChapter()
                                }
                                if position == loadedChapters.last {
                                    appendNextChapter()
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolledID, anchor: .top)
            .overlay(alignment: .trailing) {
                BibleScrubber(
                    currentPosition: visiblePosition ?? initialPosition,
                    onNavigate: { position in
                        onNavigateRequested?(position)
                    },
                    highlightManager: highlightManager
                )
            }
            .onAppear {
                loadedChapters = [initialPosition]
                scrollToChapter(initialPosition, proxy: proxy)
            }
            .onChange(of: navigationID) { _, _ in
                loadedChapters = [initialPosition]
                scrollToChapter(initialPosition, proxy: proxy)
            }
            .onChange(of: scrolledID) { _, newID in
                guard let newID else { return }
                let position = ChapterPosition(bookName: newID.bookName, chapterNumber: newID.chapterNumber)
                visiblePosition = position
                onPositionChanged?(position)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollPageUp)) { _ in
                pageScroll(up: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollPageDown)) { _ in
                pageScroll(up: false)
            }
        }
    }

    private func pageScroll(up: Bool) {
        guard let window = NSApp.keyWindow,
              let scrollView = findScrollView(in: window.contentView) else { return }
        let clipView = scrollView.contentView
        let visible = clipView.bounds
        let pageAmount = visible.height - 40 // overlap a few lines for context
        let newY = up
            ? max(visible.origin.y - pageAmount, 0)
            : min(visible.origin.y + pageAmount, scrollView.documentView!.frame.height - visible.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            clipView.animator().setBoundsOrigin(NSPoint(x: visible.origin.x, y: newY))
        }
    }

    private func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        // Look for the SwiftUI ScrollView's underlying NSScrollView (skip the inspector's)
        if let sv = view as? NSScrollView, sv.documentView is NSView, !(sv.documentView is NSTextView) {
            // Verify it's our main scroll by checking it has significant height
            if sv.frame.height > 200 {
                return sv
            }
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func scrollToChapter(_ position: ChapterPosition, proxy: ScrollViewProxy) {
        let chapterID = ChapterID(bookName: position.bookName, chapterNumber: position.chapterNumber)
        scrolledID = chapterID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo(chapterID, anchor: .top)
            if let verse = highlightVerseStart {
                let verseID = VerseAnchorID(bookName: position.bookName, chapterNumber: position.chapterNumber, verse: verse)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(verseID, anchor: UnitPoint(x: 0, y: 0.15))
                    }
                }
            }
        }
    }

    // MARK: - Chapter loading

    private func appendNextChapter() {
        guard let last = loadedChapters.last,
              let next = chapterAfter(last) else { return }
        guard !loadedChapters.contains(next) else { return }
        loadedChapters.append(next)
    }

    private func prependPreviousChapter() {
        guard let first = loadedChapters.first,
              let prev = chapterBefore(first) else { return }
        guard !loadedChapters.contains(prev) else { return }
        loadedChapters.insert(prev, at: 0)
    }

    private func chapterAfter(_ position: ChapterPosition) -> ChapterPosition? {
        guard let book = bibleStore.findBook(position.bookName) else { return nil }
        let nextNum = position.chapterNumber + 1
        if book.chapters.contains(where: { $0.number == nextNum }) {
            return ChapterPosition(bookName: position.bookName, chapterNumber: nextNum)
        }
        // Advance to the next book.
        let bookNames = BibleStore.bookNames
        guard let idx = bookNames.firstIndex(of: position.bookName),
              bookNames.indices.contains(idx + 1),
              let nextBook = bibleStore.findBook(bookNames[idx + 1]),
              let firstChapter = nextBook.chapters.first else { return nil }
        return ChapterPosition(bookName: nextBook.name, chapterNumber: firstChapter.number)
    }

    private func chapterBefore(_ position: ChapterPosition) -> ChapterPosition? {
        guard let book = bibleStore.findBook(position.bookName) else { return nil }
        let prevNum = position.chapterNumber - 1
        if book.chapters.contains(where: { $0.number == prevNum }) {
            return ChapterPosition(bookName: position.bookName, chapterNumber: prevNum)
        }
        // Go back to the previous book.
        let bookNames = BibleStore.bookNames
        guard let idx = bookNames.firstIndex(of: position.bookName),
              bookNames.indices.contains(idx - 1),
              let prevBook = bibleStore.findBook(bookNames[idx - 1]),
              let lastChapter = prevBook.chapters.last else { return nil }
        return ChapterPosition(bookName: prevBook.name, chapterNumber: lastChapter.number)
    }
}

// MARK: - Single chapter view

private struct ChapterView: View {
    let chapter: Chapter
    let bookName: String
    let isFirstChapter: Bool
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?
    let highlightManager: HighlightManager
    let notes: [Note]
    @State private var textHeight: CGFloat = 100
    @State private var verseYOffset: CGFloat?
    @State private var showNotePopover = false
    @State private var notePopoverVerseStart: Int = 1
    @State private var notePopoverVerseEnd: Int = 1
    @State private var editingNote: Note? = nil
    @State private var dropCapFontSize: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isFirstChapter {
                Text(bookName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }

            SelectableTextView(
                chapter: chapter,
                bookName: bookName,
                chapterNumber: chapter.number,
                highlights: highlightManager.highlights(forBook: bookName, chapter: chapter.number),
                searchHighlightStart: highlightVerseStart,
                searchHighlightEnd: highlightVerseEnd,
                onHighlight: { verse, startChar, endChar, color in
                    highlightManager.addHighlight(
                        book: bookName, chapter: chapter.number,
                        verse: verse, startChar: startChar, endChar: endChar, color: color
                    )
                },
                onRemoveHighlights: { verse, startChar, endChar in
                    highlightManager.removeHighlights(
                        book: bookName, chapter: chapter.number,
                        verse: verse, startChar: startChar, endChar: endChar
                    )
                },
                contentHeight: $textHeight,
                dropCapFontSize: $dropCapFontSize,
                onHighlightVerseYOffset: highlightVerseStart != nil ? { offset in
                    verseYOffset = offset
                } : nil,
                notes: notes,
                onAddNote: { verseStart, verseEnd in
                    notePopoverVerseStart = verseStart
                    notePopoverVerseEnd = verseEnd
                    editingNote = nil
                    showNotePopover = true
                },
                onEditNote: { note in
                    notePopoverVerseStart = note.verseStart
                    notePopoverVerseEnd = note.verseEnd
                    editingNote = note
                    showNotePopover = true
                }
            )
            .frame(height: textHeight)
            .overlay(alignment: .topLeading) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(chapter.number)")
                        .font(.system(size: dropCapFontSize, weight: .medium, design: .serif))
                    if highlightManager.isBookmarked(book: bookName, chapter: chapter.number) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption)
                    }
                }
                .offset(y: -4)
                .allowsHitTesting(false)
            }
            .popover(isPresented: $showNotePopover) {
                NotePopoverView(
                    book: bookName,
                    chapter: chapter.number,
                    verseStart: notePopoverVerseStart,
                    verseEnd: notePopoverVerseEnd,
                    existingNote: editingNote,
                    onSave: { rtfData in
                        if let note = editingNote {
                            highlightManager.updateNote(id: note.id, rtfData: rtfData)
                        } else {
                            highlightManager.addNote(
                                book: bookName,
                                chapter: chapter.number,
                                verseStart: notePopoverVerseStart,
                                verseEnd: notePopoverVerseEnd,
                                rtfData: rtfData
                            )
                        }
                        showNotePopover = false
                        editingNote = nil
                    },
                    onDelete: editingNote != nil ? {
                        if let note = editingNote {
                            highlightManager.removeNote(id: note.id)
                        }
                        showNotePopover = false
                        editingNote = nil
                    } : nil
                )
            }
            .padding(.horizontal, 8)
            .overlay(alignment: .topLeading) {
                if let verse = highlightVerseStart, let yOffset = verseYOffset {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(VerseAnchorID(bookName: bookName, chapterNumber: chapter.number, verse: verse))
                        .offset(y: yOffset)
                }
            }

            Divider()
                .padding(.vertical, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
