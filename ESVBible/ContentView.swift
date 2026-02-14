import SwiftUI

struct ContentView: View {
    @State private var bibleStore = BibleStore()
    @State private var historyManager = HistoryManager()
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var currentPosition: ChapterPosition? = nil
    @State private var visiblePosition: ChapterPosition? = nil
    @State private var highlightStart: Int? = nil
    @State private var highlightEnd: Int? = nil
    @State private var showHistory = false
    @State private var errorMessage: String? = nil
    @State private var isTOCVisible = false
    @State private var hoveredBook: String? = nil
    @AppStorage("lastBook") private var lastBook: String = "Genesis"
    @AppStorage("lastChapter") private var lastChapter: Int = 1
    @FocusState private var isSearchFocused: Bool
    @State private var searchService = SearchService()
    @State private var searchResults: [SearchService.VerseResult] = []
    @State private var isKeywordSearch = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack(alignment: .top) {
            // Reading pane
            Group {
                if let position = currentPosition {
                    ReadingPaneView(
                        initialPosition: position,
                        highlightVerseStart: highlightStart,
                        highlightVerseEnd: highlightEnd,
                        bibleStore: bibleStore,
                        onPositionChanged: { visiblePosition = $0 }
                    )
                } else {
                    ContentUnavailableView("Search for a passage",
                        systemImage: "book",
                        description: Text("Enter a reference like \"John 3:16\" or \"Genesis 1\""))
                }
            }

            // Tap-to-dismiss layer (before overlays so it sits behind them)
            if isSearchVisible || isTOCVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        if isSearchVisible { dismissSearch() }
                        if isTOCVisible { dismissTOC() }
                    }
            }

            // Floating search bar overlay
            if isSearchVisible {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .imageScale(.large)

                        TextField("Search verses or go to reference...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($isSearchFocused)
                            .onSubmit { performSearch() }
                            .onChange(of: searchText) { _, newValue in
                                searchTask?.cancel()
                                errorMessage = nil

                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else {
                                    searchResults = []
                                    isKeywordSearch = false
                                    return
                                }

                                // If it parses as a reference, clear keyword results
                                if ReferenceParser.parse(trimmed) != nil {
                                    searchResults = []
                                    isKeywordSearch = false
                                    return
                                }

                                // Debounce keyword search
                                isKeywordSearch = true
                                searchTask = Task {
                                    try? await Task.sleep(for: .milliseconds(300))
                                    guard !Task.isCancelled else { return }
                                    let results = searchService.search(query: trimmed, bibleStore: bibleStore)
                                    await MainActor.run {
                                        searchResults = results
                                    }
                                }
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)

                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }

                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(searchResults.count)\(searchResults.count >= 50 ? "+" : "") result\(searchResults.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)

                                Divider()

                                ForEach(searchResults) { result in
                                    Button {
                                        dismissSearch()
                                        navigateTo(book: result.book, chapter: result.chapter, verseStart: result.verse, verseEnd: result.verse, addToHistory: true)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(result.book) \(result.chapter):\(result.verse)")
                                                .font(.subheadline.bold())
                                            Text(result.text)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)

                                    if result.id != searchResults.last?.id {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 48)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            // Table of Contents overlay
            if isTOCVisible {
                tocOverlay
                    .transition(.opacity)
            }
        }
        .inspector(isPresented: $showHistory) {
            HistorySidebarView(
                entries: historyManager.entries,
                onSelect: { entry in
                    navigateToHistory(entry)
                },
                onClear: {
                    historyManager.clearHistory()
                }
            )
            .frame(minWidth: 150, maxWidth: 300)
        }
        .navigationTitle(currentTitle)
        .frame(minWidth: 400, minHeight: 500)
        .toolbar(.hidden)
        .onAppear {
            navigateTo(book: lastBook, chapter: lastChapter, verseStart: nil, verseEnd: nil, addToHistory: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousChapter)) { _ in
            navigateChapter(delta: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateNextChapter)) { _ in
            navigateChapter(delta: 1)
        }
        .onKeyPress(.escape) {
            if isSearchVisible {
                dismissSearch()
                return .handled
            }
            if isTOCVisible {
                dismissTOC()
                return .handled
            }
            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSearch)) { _ in
            showSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTableOfContents)) { _ in
            toggleTOC()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { _ in
            showHistory.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToReference)) { notification in
            if let book = notification.userInfo?["book"] as? String,
               let chapter = notification.userInfo?["chapter"] as? Int {
                let verse = notification.userInfo?["verse"] as? Int
                navigateTo(book: book, chapter: chapter, verseStart: verse, verseEnd: verse, addToHistory: true)
            }
        }
    }

    private var currentTitle: String {
        let position = visiblePosition ?? currentPosition
        guard let position else { return "ESV Bible" }
        return "\(position.bookName) \(position.chapterNumber)"
    }

    private func showSearch() {
        searchText = ""
        errorMessage = nil
        withAnimation(.spring(duration: 0.25)) {
            isSearchVisible = true
        }
        // Give SwiftUI a moment to render the field before focusing it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isSearchFocused = true
        }
    }

    private func dismissSearch() {
        withAnimation(.spring(duration: 0.2)) {
            isSearchVisible = false
        }
        isSearchFocused = false
        searchResults = []
        isKeywordSearch = false
        searchTask?.cancel()
    }

    private func toggleTOC() {
        if isTOCVisible {
            dismissTOC()
        } else {
            withAnimation(.spring(duration: 0.25)) {
                isTOCVisible = true
            }
            hoveredBook = nil
        }
    }

    private func dismissTOC() {
        withAnimation(.spring(duration: 0.2)) {
            isTOCVisible = false
        }
        hoveredBook = nil
    }

    private var tocOverlay: some View {
        HStack(alignment: .top, spacing: 0) {
            // Book list
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Old Testament")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    ForEach(BibleStore.bookNames.prefix(39), id: \.self) { book in
                        tocBookRow(book)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("New Testament")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)

                    ForEach(Array(BibleStore.bookNames.suffix(from: 39)), id: \.self) { book in
                        tocBookRow(book)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 180)

            Divider()

            // Chapter grid
            if let book = hoveredBook, let foundBook = bibleStore.findBook(book) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 4), count: 6), spacing: 4) {
                            ForEach(foundBook.chapters) { chapter in
                                Button {
                                    dismissTOC()
                                    navigateTo(book: book, chapter: chapter.number, verseStart: nil, verseEnd: nil, addToHistory: true)
                                } label: {
                                    Text("\(chapter.number)")
                                        .frame(width: 40, height: 32)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: 280)
            } else {
                VStack {
                    Spacer()
                    Text("Hover over a book to see chapters")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(width: 280)
            }
        }
        .frame(height: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
    }

    private func tocBookRow(_ book: String) -> some View {
        Text(book)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(hoveredBook == book ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .onHover { isHovered in
                if isHovered {
                    hoveredBook = book
                }
            }
            .onTapGesture {
                dismissTOC()
                navigateTo(book: book, chapter: 1, verseStart: nil, verseEnd: nil, addToHistory: true)
            }
    }

    private func performSearch() {
        errorMessage = nil

        // If we have keyword results showing, navigate to first result on Enter
        if isKeywordSearch && !searchResults.isEmpty {
            let first = searchResults[0]
            dismissSearch()
            navigateTo(book: first.book, chapter: first.chapter, verseStart: first.verse, verseEnd: first.verse, addToHistory: true)
            return
        }

        guard let ref = ReferenceParser.parse(searchText) else {
            // If not a reference, trigger keyword search immediately
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                isKeywordSearch = true
                searchResults = searchService.search(query: searchText.trimmingCharacters(in: .whitespaces), bibleStore: bibleStore)
                if searchResults.isEmpty {
                    errorMessage = "No results found."
                }
            } else {
                errorMessage = "Enter a reference or keyword to search."
            }
            return
        }
        dismissSearch()
        navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
    }

    private func navigateTo(book: String, chapter: Int, verseStart: Int?, verseEnd: Int?, addToHistory: Bool) {
        guard let foundBook = bibleStore.findBook(book) else {
            errorMessage = "Book not found: \(book)"
            return
        }
        guard foundBook.chapters.first(where: { $0.number == chapter }) != nil else {
            errorMessage = "Chapter \(chapter) not found in \(foundBook.name)"
            return
        }
        currentPosition = ChapterPosition(bookName: foundBook.name, chapterNumber: chapter)
        highlightStart = verseStart
        highlightEnd = verseEnd
        errorMessage = nil
        lastBook = foundBook.name
        lastChapter = chapter

        if addToHistory {
            let ref = BibleReference(book: foundBook.name, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd)
            historyManager.addEntry(for: ref)
        }
    }

    private func navigateToHistory(_ entry: HistoryEntry) {
        showHistory = false // Hide inspector on selection
        navigateTo(book: entry.bookName, chapter: entry.chapter, verseStart: entry.verseStart, verseEnd: entry.verseEnd, addToHistory: false)
    }

    private func navigateChapter(delta: Int) {
        let position = visiblePosition ?? currentPosition
        guard let position,
              let book = bibleStore.findBook(position.bookName) else { return }

        let newChapterNum = position.chapterNumber + delta

        if book.chapters.contains(where: { $0.number == newChapterNum }) {
            // Still within the same book.
            currentPosition = ChapterPosition(bookName: position.bookName, chapterNumber: newChapterNum)
            highlightStart = nil
            highlightEnd = nil
        } else {
            // Cross a book boundary.
            let bookNames = BibleStore.bookNames
            guard let currentBookIndex = bookNames.firstIndex(of: position.bookName) else { return }
            let nextBookIndex = currentBookIndex + delta

            guard bookNames.indices.contains(nextBookIndex),
                  let nextBook = bibleStore.findBook(bookNames[nextBookIndex]) else { return }

            // When going forward, land on chapter 1; when going back, land on the last chapter.
            let targetChapter = delta > 0
                ? nextBook.chapters.first
                : nextBook.chapters.last

            guard let targetChapter else { return }
            currentPosition = ChapterPosition(bookName: nextBook.name, chapterNumber: targetChapter.number)
            highlightStart = nil
            highlightEnd = nil
        }
    }
}
