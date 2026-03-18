import SwiftUI

struct VerseRangeView: View {
    let references: [BibleReference]
    let bibleStore: BibleStore

    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(references.enumerated()), id: \.offset) { index, ref in
                    referenceSection(ref)

                    if index < references.count - 1 {
                        Divider()
                            .padding(.vertical, 24)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(readingTheme.backgroundColor.ignoresSafeArea())
        .navigationTitle(windowTitle)
        .preferredColorScheme(readingTheme.colorScheme)
    }

    // MARK: - Window title

    private var windowTitle: String {
        references.map { $0.displayString }.joined(separator: " \u{00B7} ")
    }

    // MARK: - Per-reference section

    @ViewBuilder
    private func referenceSection(_ ref: BibleReference) -> some View {
        let sections = collectSections(for: ref)

        VStack(alignment: .leading, spacing: 12) {
            Text(ref.displayString)
                .font(.headline)
                .foregroundStyle(Color(readingTheme.nsTextColor))

            if sections.isEmpty {
                Text("Not found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sections, id: \.id) { section in
                    verseSectionView(section)
                }
            }
        }
    }

    @ViewBuilder
    private func verseSectionView(_ section: VerseSection) -> some View {
        if section.verses.isEmpty {
            Text("Chapter not found")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(section.verses) { verse in
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(verse.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, alignment: .trailing)
                            .padding(.top, 2)
                        Text(verse.text)
                            .font(.custom(selectedFont, size: 16))
                            .foregroundStyle(Color(readingTheme.nsTextColor))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Verse collection

    private struct VerseSection: Identifiable {
        let id: String   // "bookName-chapterNum"
        let verses: [Verse]
    }

    private func collectSections(for ref: BibleReference) -> [VerseSection] {
        if ref.endBook != nil || ref.endChapter != nil {
            return collectRangeSections(for: ref)
        }

        // Simple single-chapter reference
        guard let book = bibleStore.findBook(ref.book),
              let chapter = book.chapters.first(where: { $0.number == ref.chapter }) else {
            return []
        }

        let verses: [Verse]
        if let start = ref.verseStart {
            let end = ref.verseEnd ?? start
            verses = chapter.verses.filter { $0.number >= start && $0.number <= end }
        } else {
            verses = chapter.verses
        }

        return [VerseSection(id: "\(book.name)-\(chapter.number)", verses: verses)]
    }

    private func collectRangeSections(for ref: BibleReference) -> [VerseSection] {
        var result: [VerseSection] = []

        let startBookName = ref.book
        let startChapter = ref.chapter
        let startVerse = ref.verseStart ?? 1

        let endBookName = ref.endBook ?? ref.book
        let endChapter = ref.endChapter ?? ref.chapter
        let endVerse = ref.verseEnd

        // Get all book names from startBook to endBook in canonical order
        let bookNames = BibleStore.bookNames
        guard let startBookIdx = bookNames.firstIndex(of: resolveBookName(startBookName)),
              let endBookIdx   = bookNames.firstIndex(of: resolveBookName(endBookName)),
              startBookIdx <= endBookIdx else {
            return []
        }

        let booksInRange = Array(bookNames[startBookIdx...endBookIdx])

        for (bi, bookName) in booksInRange.enumerated() {
            guard let book = bibleStore.findBook(bookName) else {
                result.append(VerseSection(id: "\(bookName)-missing", verses: []))
                continue
            }

            let isFirstBook = bi == 0
            let isLastBook  = bi == booksInRange.count - 1

            let chapStart = isFirstBook ? startChapter : 1
            let chapEnd   = isLastBook  ? endChapter   : (book.chapters.last?.number ?? 1)

            for chNum in chapStart...chapEnd {
                guard let chapter = book.chapters.first(where: { $0.number == chNum }) else {
                    result.append(VerseSection(id: "\(bookName)-\(chNum)-missing", verses: []))
                    continue
                }

                let verses: [Verse]
                if isFirstBook && chNum == startChapter && isLastBook && chNum == endChapter {
                    // Only chapter in range — apply both start and end filters
                    verses = chapter.verses.filter {
                        $0.number >= startVerse && $0.number <= (endVerse ?? Int.max)
                    }
                } else if isFirstBook && chNum == startChapter {
                    verses = chapter.verses.filter { $0.number >= startVerse }
                } else if isLastBook && chNum == endChapter {
                    verses = chapter.verses.filter { $0.number <= (endVerse ?? Int.max) }
                } else {
                    verses = chapter.verses
                }

                result.append(VerseSection(id: "\(bookName)-\(chNum)", verses: verses))
            }
        }

        return result
    }

    /// Resolves a potentially abbreviated book name to a canonical `BibleStore.bookNames` entry.
    private func resolveBookName(_ name: String) -> String {
        bibleStore.findBook(name)?.name ?? name
    }
}
