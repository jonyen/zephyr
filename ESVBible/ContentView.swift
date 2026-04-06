import SwiftUI

struct ContentView: View {
    let initialPosition: ChapterPosition?

    @State private var bibleStore = BibleStore()
    @State private var historyManager = HistoryManager()
    @State private var highlightManager = HighlightManager()
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var currentPosition: ChapterPosition? = nil
    @State private var visiblePosition: ChapterPosition? = nil
    @State private var highlightStart: Int? = nil
    @State private var highlightEnd: Int? = nil
    @State private var showHistory = false
    @State private var showNotes = false
    @State private var errorMessage: String? = nil
    @State private var isTOCVisible = false
    @State private var hoveredBook: String? = nil
    @State private var showKeyboardShortcuts = false
    @AppStorage("lastBook") private var lastBook: String = "Genesis"
    @AppStorage("lastChapter") private var lastChapter: Int = 1
    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system
    @AppStorage("keybinding_search") private var searchKey = "k"
    @AppStorage("keybinding_prevChapter") private var prevChapterKey = "["
    @AppStorage("keybinding_nextChapter") private var nextChapterKey = "]"
    @AppStorage("keybinding_history") private var historyKey = "y"
    @AppStorage("keybinding_notes") private var notesKey = "n"
    @AppStorage("keybinding_bookmark") private var bookmarkKey = "b"
    @FocusState private var isSearchFocused: Bool
    @State private var keyMonitor: Any? = nil
    @State private var searchService = SearchService()
    @State private var searchResults: [SearchService.VerseResult] = []
    @State private var isKeywordSearch = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var parsedReference: BibleReference? = nil
    @State private var parsedMultiReference: [BibleReference]? = nil
    @State private var navigationCounter: Int = 0
    @State private var updateService = UpdateService()
    @State private var readingTimerService = ReadingTimerService()
    @State private var hostWindow: NSWindow? = nil
    @State private var hasAppeared = false
    @State private var windowCloseObserver: Any? = nil
    var body: some View {
        mainContent
        .preferredColorScheme(readingTheme.colorScheme)
        .background(readingTheme.backgroundColor.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousBookmark)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            navigateToBookmark(direction: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateNextBookmark)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            navigateToBookmark(direction: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousHighlight)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            navigateToHighlight(direction: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateNextHighlight)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            navigateToHighlight(direction: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            showKeyboardShortcuts.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToReference)) { notification in
            guard isForThisWindow(notification) else { return }
            if let book = notification.userInfo?["book"] as? String,
               let chapter = notification.userInfo?["chapter"] as? Int {
                let verse = notification.userInfo?["verse"] as? Int
                navigateTo(book: book, chapter: chapter, verseStart: verse, verseEnd: verse, addToHistory: true)
            }
        }
    }

    /// Window-scoped commands carry their target window. A nil target means the sender had no
    /// particular window in mind (app launch, Spotlight before any tab exists), so take it.
    private func isForThisWindow(_ notification: Notification) -> Bool {
        guard let target = notification.object as? NSWindow else { return true }
        return target == hostWindow
    }

    private var mainContent: some View {
        ZStack(alignment: .top) {
            // Reading pane
            Group {
                if let position = currentPosition {
                    ReadingPaneView(
                        initialPosition: position,
                        navigationID: navigationCounter,
                        highlightVerseStart: highlightStart,
                        highlightVerseEnd: highlightEnd,
                        bibleStore: bibleStore,
                        highlightManager: highlightManager,
                        hostWindow: hostWindow,
                        onPositionChanged: { visiblePosition = $0 },
                        onNavigateRequested: { pos in
                            navigateTo(book: pos.bookName, chapter: pos.chapterNumber, verseStart: nil, verseEnd: nil, addToHistory: false)
                        }
                    )
                } else {
                    ContentUnavailableView("Search for a passage",
                        systemImage: "book",
                        description: Text("Enter a reference like \"John 3:16\" or \"Genesis 1\""))
                }
            }

            // Update banner overlay
            UpdateBannerView(updateService: updateService)
                .zIndex(5)

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
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            // Table of Contents overlay
            if isTOCVisible {
                tocOverlay
                    .transition(.opacity)
            }

            // Keyboard shortcuts overlay
            if showKeyboardShortcuts {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showKeyboardShortcuts = false }

                keyboardShortcutsOverlay
                    .transition(.opacity)
            }
            WindowAccessor(window: $hostWindow)
                .frame(width: 0, height: 0)

            // Reading timer in title bar area
            VStack {
                HStack {
                    Spacer()
                    ReadingTimerView(timerService: readingTimerService)
                        .padding(.trailing, 12)
                        .padding(.top, 4)
                }
                Spacer()
            }
        }
        .inspector(isPresented: Binding(
            get: { showHistory || showNotes },
            set: { newValue in
                if !newValue {
                    showHistory = false
                    showNotes = false
                }
            }
        )) {
            if showNotes {
                NotesSidebarView(
                    notes: highlightManager.notes,
                    onSelect: { note in
                        showNotes = false
                        navigateTo(book: note.book, chapter: note.chapter, verseStart: note.verseStart, verseEnd: note.verseEnd, addToHistory: true)
                    },
                    onDelete: { id in
                        highlightManager.removeNote(id: id)
                    }
                )
                .frame(minWidth: 150, maxWidth: 300)
            } else {
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
        }
        .navigationTitle(currentTitle)
        .frame(minWidth: 400, minHeight: 500)
        .toolbar(.hidden)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true

            // Every tab installs a monitor and they all see every key press, so each one must
            // stand down unless its own window is frontmost.
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard hostWindow != nil, NSApp.keyWindow == hostWindow else { return event }

                if event.charactersIgnoringModifiers == "?" && !isSearchVisible {
                    showKeyboardShortcuts.toggle()
                    return nil
                }
                if event.keyCode == 53 /* Escape */ && showKeyboardShortcuts {
                    showKeyboardShortcuts = false
                    return nil
                }
                // Page Up (fn+up) / Page Down (fn+down)
                if event.specialKey == .pageUp {
                    NotificationCenter.default.post(name: .scrollPageUp, object: hostWindow)
                    return nil
                }
                if event.specialKey == .pageDown {
                    NotificationCenter.default.post(name: .scrollPageDown, object: hostWindow)
                    return nil
                }
                return event
            }

            if let initial = initialPosition {
                navigateTo(book: initial.bookName, chapter: initial.chapterNumber, verseStart: nil, verseEnd: nil, addToHistory: false)
            } else if let pending = AppDelegate.pendingNavigation {
                AppDelegate.pendingNavigation = nil
                navigateTo(book: pending.book, chapter: pending.chapter, verseStart: pending.verse, verseEnd: pending.verse, addToHistory: true)
            } else {
                navigateTo(book: lastBook, chapter: lastChapter, verseStart: nil, verseEnd: nil, addToHistory: false)
            }
            Task {
                await updateService.checkForUpdate()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigatePreviousChapter)) { (notification: Notification) in
            guard (notification.object as? NSWindow) == hostWindow else { return }
            navigateChapter(delta: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateNextChapter)) { (notification: Notification) in
            guard (notification.object as? NSWindow) == hostWindow else { return }
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
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            if let observer = windowCloseObserver {
                NotificationCenter.default.removeObserver(observer)
                windowCloseObserver = nil
            }
        }
        .onChange(of: hostWindow) { _, newWindow in
            guard let window = newWindow else { return }
            registerPosition()
            // This tab may have been opened to service a command from a verse card.
            TabCoordinator.shared.drainPendingCommands(for: window)
            guard windowCloseObserver == nil else { return }
            windowCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [self] _ in
                if let position = self.visiblePosition ?? self.currentPosition {
                    ClosedTabsStack.shared.push(position)
                }
                MainActor.assumeIsolated { TabCoordinator.shared.unregister(window: window) }
            }
        }
        .onChange(of: currentPosition) { _, _ in registerPosition() }
        .onChange(of: visiblePosition) { _, _ in registerPosition() }
        .onReceive(NotificationCenter.default.publisher(for: .showSearch)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            showSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTableOfContents)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            toggleTOC()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            if showNotes { showNotes = false }
            showHistory.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleNotes)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            if showHistory { showHistory = false }
            showNotes.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .checkForUpdates)) { _ in
            Task {
                await updateService.checkForUpdate(manual: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleBookmark)) { (notification: Notification) in
            guard isForThisWindow(notification) else { return }
            let position = visiblePosition ?? currentPosition
            guard let position else { return }
            highlightManager.toggleBookmark(book: position.bookName, chapter: position.chapterNumber)
        }
    }

    /// Tells the tab coordinator where this window is parked, so a tab spawned from it
    /// (or from a verse-range tab that has no reading position of its own) lands sensibly.
    private func registerPosition() {
        guard let window = hostWindow,
              let position = visiblePosition ?? currentPosition else { return }
        TabCoordinator.shared.register(window: window, position: position)
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
        parsedReference = nil
        parsedMultiReference = nil
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

    @ViewBuilder
    private var searchOverlay: some View {
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
                            parsedReference = nil
                            parsedMultiReference = nil
                            isKeywordSearch = false
                            return
                        }

                        // Try to parse as one or more Bible references
                        if let refs = ReferenceParser.parseMultiple(trimmed), !refs.isEmpty {
                            // Validate: all referenced book+chapters must exist (including endBook/endChapter for ranges)
                            let allValid = refs.allSatisfy { ref in
                                let startOk = bibleStore.findBook(ref.book)?.chapters.first(where: { $0.number == ref.chapter }) != nil
                                let endOk: Bool
                                if let eb = ref.endBook, let ec = ref.endChapter {
                                    endOk = bibleStore.findBook(eb)?.chapters.first(where: { $0.number == ec }) != nil
                                } else if let ec = ref.endChapter {
                                    endOk = bibleStore.findBook(ref.book)?.chapters.first(where: { $0.number == ec }) != nil
                                } else {
                                    endOk = true
                                }
                                return startOk && endOk
                            }
                            if allValid {
                                // Cross-book range canonical ordering check
                                let isValidOrder: Bool
                                if refs.count == 1, let endBook = refs[0].endBook, let endChapter = refs[0].endChapter {
                                    let startCanonical = bibleStore.findBook(refs[0].book)?.name ?? refs[0].book
                                    let endCanonical   = bibleStore.findBook(endBook)?.name ?? endBook
                                    isValidOrder = BibleStore.globalChapterIndex(book: endCanonical, chapter: endChapter)
                                                 > BibleStore.globalChapterIndex(book: startCanonical, chapter: refs[0].chapter)
                                } else {
                                    isValidOrder = true
                                }

                                if isValidOrder {
                                    searchResults = []
                                    isKeywordSearch = false
                                    searchTask?.cancel()

                                    if refs.count >= 2 {
                                        parsedMultiReference = refs
                                        parsedReference = nil
                                    } else {
                                        parsedMultiReference = nil
                                        parsedReference = refs[0]
                                    }
                                    return
                                }
                            }
                            // Invalid references — fall through to keyword search
                            parsedReference = nil
                            parsedMultiReference = nil
                        }
                        parsedReference = nil
                        parsedMultiReference = nil

                        // Keyword search (existing logic — keep unchanged)
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

            if parsedReference != nil || parsedMultiReference != nil || !searchResults.isEmpty {
                searchResultsList
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 48)
    }

    /// A parsed-reference row: the reference, and the opening words of the verse it points at so
    /// you can confirm you typed the one you meant without opening it.
    private func referenceRow(title: String, preview: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color.accentColor)
                    .imageScale(.small)
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "return")
                    .foregroundStyle(.tertiary)
                    .imageScale(.small)
            }

            if let preview {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var searchResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let refs = parsedMultiReference {
                    // Multi-reference row
                    Button {
                        openVerseRangeTab(references: refs)
                    } label: {
                        referenceRow(
                            title: refs.map { $0.displayString }.joined(separator: " \u{00B7} "),
                            preview: refs.first.flatMap { bibleStore.previewText(for: $0) }
                        )
                    }
                    .buttonStyle(.plain)

                    if !searchResults.isEmpty { Divider() }
                } else if let ref = parsedReference {
                    Button {
                        if ref.verseStart != nil {
                            // Verse reference → open focused tab
                            openVerseRangeTab(references: [ref])
                        } else {
                            // Whole chapter → navigate in current tab
                            dismissSearch()
                            navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
                        }
                    } label: {
                        referenceRow(title: ref.displayString,
                                     preview: bibleStore.previewText(for: ref))
                    }
                    .buttonStyle(.plain)

                    if !searchResults.isEmpty { Divider() }
                }

                if !searchResults.isEmpty {
                    Text("\(searchResults.count)\(searchResults.count >= 50 ? "+" : "") result\(searchResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    Divider()
                }

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
        // ScrollView is greedy and `maxHeight` is a flexible cap, so on its own the box always
        // paints a full 300pt. Wrapping the capped frame in fixedSize asks for its ideal height
        // instead — the content height, clamped to 300 — so the box hugs one result and still
        // scrolls once there are many. The order matters: fixedSize has to be the outer one.
        .frame(maxHeight: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
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

    private var keyboardShortcutsOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showKeyboardShortcuts = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(spacing: 10) {
                ForEach(shortcutItems, id: \.action) { item in
                    HStack {
                        Text(item.action)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.keys)
                            .font(.system(.body, design: .rounded).bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
    }

    private var shortcutItems: [(action: String, keys: String)] {
        [
            ("Search for Passage", "\u{2318}F / \u{2318}\(searchKey.uppercased())"),
            ("Toggle History", "\u{2318}\(historyKey.uppercased())"),
            ("Toggle Notes", "\u{2318}\(notesKey.uppercased())"),
            ("Previous Chapter", "\u{2318}\(prevChapterKey.uppercased())"),
            ("Next Chapter", "\u{2318}\(nextChapterKey.uppercased())"),
            ("Toggle Bookmark", "\u{2318}\(bookmarkKey.uppercased())"),
            ("Previous Bookmark", "\u{21E7}\u{2318}\u{2190}"),
            ("Next Bookmark", "\u{21E7}\u{2318}\u{2192}"),
            ("Previous Highlight", "\u{2318}\u{2190}"),
            ("Next Highlight", "\u{2318}\u{2192}"),
            ("Previous Tab", "\u{21E7}\u{2318}["),
            ("Next Tab", "\u{21E7}\u{2318}]"),
            ("New Tab", "\u{2318}T"),
            ("Reopen Closed Tab", "\u{21E7}\u{2318}T"),
            ("Keep Window on Top", "\u{21E7}\u{2318}P"),
            ("Check for Updates", "\u{21E7}\u{2318}U"),
            ("Show Shortcuts", "?"),
            ("Dismiss", "Esc"),
        ]
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

        // Multi-reference → open tab
        if let refs = parsedMultiReference {
            openVerseRangeTab(references: refs)
            return
        }

        guard let ref = parsedReference else {
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

        if ref.verseStart != nil {
            openVerseRangeTab(references: [ref])
        } else {
            dismissSearch()
            navigateTo(book: ref.book, chapter: ref.chapter, verseStart: ref.verseStart, verseEnd: ref.verseEnd, addToHistory: true)
        }
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
        let newPosition = ChapterPosition(bookName: foundBook.name, chapterNumber: chapter)
        highlightStart = verseStart
        highlightEnd = verseEnd
        currentPosition = newPosition
        visiblePosition = newPosition
        navigationCounter += 1
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

    private func navigateToBookmark(direction: Int) {
        let position = visiblePosition ?? currentPosition
        guard let position else { return }
        let bookmarks = highlightManager.bookmarks
        guard !bookmarks.isEmpty else { return }

        let currentIndex = BibleStore.globalChapterIndex(book: position.bookName, chapter: position.chapterNumber)

        // Sort bookmarks by their position in the Bible
        let sorted = bookmarks
            .map { (bookmark: $0, index: BibleStore.globalChapterIndex(book: $0.book, chapter: $0.chapter)) }
            .sorted { $0.index < $1.index }

        let target: (bookmark: Bookmark, index: Int)?
        if direction > 0 {
            // Next: first bookmark after current position, or wrap to first
            target = sorted.first(where: { $0.index > currentIndex }) ?? sorted.first
        } else {
            // Previous: last bookmark before current position, or wrap to last
            target = sorted.last(where: { $0.index < currentIndex }) ?? sorted.last
        }

        if let target {
            navigateTo(book: target.bookmark.book, chapter: target.bookmark.chapter, verseStart: nil, verseEnd: nil, addToHistory: true)
        }
    }

    private func navigateToHighlight(direction: Int) {
        let position = visiblePosition ?? currentPosition
        guard let position else { return }
        let highlights = highlightManager.highlights
        guard !highlights.isEmpty else { return }

        let currentIndex = BibleStore.globalChapterIndex(book: position.bookName, chapter: position.chapterNumber)

        // Sort all highlights by Bible position (chapter then verse)
        let sorted = highlights
            .map { h in (highlight: h, index: BibleStore.globalChapterIndex(book: h.book, chapter: h.chapter)) }
            .sorted { a, b in
                if a.index != b.index { return a.index < b.index }
                return a.highlight.verse < b.highlight.verse
            }

        let target: (highlight: Highlight, index: Int)?
        if direction > 0 {
            target = sorted.first(where: { $0.index > currentIndex || ($0.index == currentIndex && $0.highlight.verse > (highlightStart ?? 0)) }) ?? sorted.first
        } else {
            target = sorted.last(where: { $0.index < currentIndex || ($0.index == currentIndex && $0.highlight.verse < (highlightStart ?? Int.max)) }) ?? sorted.last
        }

        if let target {
            navigateTo(book: target.highlight.book, chapter: target.highlight.chapter, verseStart: target.highlight.verse, verseEnd: target.highlight.verse, addToHistory: true)
        }
    }

    private func openVerseRangeTab(references: [BibleReference]) {
        guard let host = hostWindow else {
            errorMessage = "No host window available."
            return
        }
        TabCoordinator.shared.openVerseRangeTab(from: host, references: references, bibleStore: bibleStore)
        dismissSearch()
    }

    private func navigateChapter(delta: Int) {
        let position = visiblePosition ?? currentPosition
        guard let position,
              let book = bibleStore.findBook(position.bookName) else { return }

        let newChapterNum = position.chapterNumber + delta

        if book.chapters.contains(where: { $0.number == newChapterNum }) {
            navigateTo(book: position.bookName, chapter: newChapterNum, verseStart: nil, verseEnd: nil, addToHistory: false)
        } else {
            // Cross a book boundary.
            let bookNames = BibleStore.bookNames
            guard let currentBookIndex = bookNames.firstIndex(of: position.bookName) else { return }
            let nextBookIndex = currentBookIndex + delta

            guard bookNames.indices.contains(nextBookIndex),
                  let nextBook = bibleStore.findBook(bookNames[nextBookIndex]) else { return }

            let targetChapter = delta > 0
                ? nextBook.chapters.first
                : nextBook.chapters.last

            guard let targetChapter else { return }
            navigateTo(book: nextBook.name, chapter: targetChapter.number, verseStart: nil, verseEnd: nil, addToHistory: false)
        }
    }
}
