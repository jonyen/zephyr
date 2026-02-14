import SwiftUI

// Uniquely identifies a rendered chapter in the scroll view.
private struct ChapterID: Hashable {
    let bookName: String
    let chapterNumber: Int
}

struct ReadingPaneView: View {
    let initialPosition: ChapterPosition
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?
    let bibleStore: BibleStore
    /// Called whenever the topmost visible chapter changes.
    var onPositionChanged: ((ChapterPosition) -> Void)?

    // The ordered list of chapters currently in the scroll view.
    @State private var loadedChapters: [ChapterPosition] = []
    @State private var scrolledID: ChapterID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(loadedChapters, id: \.self) { position in
                    if let book = bibleStore.findBook(position.bookName),
                       let chapter = book.chapters.first(where: { $0.number == position.chapterNumber }) {
                        ChapterView(
                            chapter: chapter,
                            bookName: book.name,
                            highlightVerseStart: position == initialPosition ? highlightVerseStart : nil,
                            highlightVerseEnd: position == initialPosition ? highlightVerseEnd : nil
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
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledID, anchor: .top)
        .onAppear {
            loadedChapters = [initialPosition]
            scrolledID = ChapterID(bookName: initialPosition.bookName, chapterNumber: initialPosition.chapterNumber)
        }
        .onChange(of: initialPosition) { _, newPosition in
            // A new navigation was requested — reset the list.
            loadedChapters = [newPosition]
            scrolledID = ChapterID(bookName: newPosition.bookName, chapterNumber: newPosition.chapterNumber)
        }
        .onChange(of: scrolledID) { _, newID in
            guard let newID else { return }
            let position = ChapterPosition(bookName: newID.bookName, chapterNumber: newID.chapterNumber)
            onPositionChanged?(position)
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
    let highlightVerseStart: Int?
    let highlightVerseEnd: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(bookName) \(chapter.number)")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.bottom, 16)

            paragraphText
                .font(.system(size: 16, design: .serif))
                .lineSpacing(6)
                .padding(.horizontal, 8)

            Divider()
                .padding(.vertical, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paragraphText: Text {
        var result = Text("")
        for verse in chapter.verses {
            let verseNum = Text("\(verse.number) ")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .baselineOffset(6)
            let verseText: Text
            if isHighlighted(verse.number) {
                verseText = Text(verse.text + " ")
                    .foregroundStyle(Color.accentColor)
            } else {
                verseText = Text(verse.text + " ")
            }
            result = result + verseNum + verseText
        }
        return result
    }

    private func isHighlighted(_ verseNumber: Int) -> Bool {
        guard let start = highlightVerseStart else { return false }
        let end = highlightVerseEnd ?? start
        return verseNumber >= start && verseNumber <= end
    }
}
