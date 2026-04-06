import SwiftUI
import CoreSpotlight

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Stores a pending navigation from Spotlight or URL scheme that arrived before the UI was ready.
    static var pendingNavigation: (book: String, chapter: Int, verse: Int?)?

    private func navigate(book: String, chapter: Int, verse: Int?) {
        let userInfo: [String: Any] = [
            "book": book,
            "chapter": chapter,
            "verse": verse as Any
        ]
        // Post now and also store as pending in case the view isn't listening yet.
        Self.pendingNavigation = (book, chapter, verse)
        MainActor.assumeIsolated {
            TabCoordinator.shared.route(.navigateToReference, from: NSApp.keyWindow, userInfo: userInfo)
        }
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let parsed = SpotlightIndexer.parseIdentifier(identifier) else {
            return false
        }
        navigate(book: parsed.book, chapter: parsed.chapter, verse: parsed.verse)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "zephyr" else { return }
        let components = [url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" }
        guard !components.isEmpty else { return }

        let book = components[0]
        let chapter = components.count > 1 ? Int(components[1]) ?? 1 : 1
        let verse = components.count > 2 ? Int(components[2]) : nil

        navigate(book: book, chapter: chapter, verse: verse)
    }
}

@main
struct ESVBibleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("keybinding_search") private var searchKey = "k"
    @AppStorage("keybinding_prevChapter") private var prevChapterKey = "["
    @AppStorage("keybinding_nextChapter") private var nextChapterKey = "]"
    @AppStorage("keybinding_history") private var historyKey = "y"
    @AppStorage("keybinding_notes") private var notesKey = "n"
    @AppStorage("keybinding_bookmark") private var bookmarkKey = "b"

    init() {
        SpotlightIndexer.indexIfNeeded()
    }

    var body: some Scene {
        WindowGroup(for: ChapterPosition.self) { $position in
            ContentView(initialPosition: position)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Search for Passage") {
                    TabCoordinator.shared.route(.showSearch, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(searchKey.first ?? "k"), modifiers: .command)

                Button("Search for Passage") {
                    TabCoordinator.shared.route(.showSearch, from: NSApp.keyWindow)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Go to Previous Chapter") {
                    TabCoordinator.shared.route(.navigatePreviousChapter, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(prevChapterKey.first ?? "["), modifiers: .command)

                Button("Go to Next Chapter") {
                    TabCoordinator.shared.route(.navigateNextChapter, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(nextChapterKey.first ?? "]"), modifiers: .command)

                Divider()

                Button("Table of Contents") {
                    TabCoordinator.shared.route(.showTableOfContents, from: NSApp.keyWindow)
                }

                Button("Toggle History") {
                    TabCoordinator.shared.route(.toggleHistory, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(historyKey.first ?? "y"), modifiers: .command)

                Button("Toggle Notes") {
                    TabCoordinator.shared.route(.toggleNotes, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(notesKey.first ?? "n"), modifiers: .command)

                Divider()

                Button("Toggle Bookmark") {
                    TabCoordinator.shared.route(.toggleBookmark, from: NSApp.keyWindow)
                }
                .keyboardShortcut(KeyEquivalent(bookmarkKey.first ?? "b"), modifiers: .command)

                Button("Previous Bookmark") {
                    TabCoordinator.shared.route(.navigatePreviousBookmark, from: NSApp.keyWindow)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

                Button("Next Bookmark") {
                    TabCoordinator.shared.route(.navigateNextBookmark, from: NSApp.keyWindow)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])

                Button("Previous Highlight") {
                    TabCoordinator.shared.route(.navigatePreviousHighlight, from: NSApp.keyWindow)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("Next Highlight") {
                    TabCoordinator.shared.route(.navigateNextHighlight, from: NSApp.keyWindow)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Divider()

                Button("Reading Timer") {
                    NotificationCenter.default.post(name: .toggleReadingTimer, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                Button("New Tab") {
                    TabCoordinator.shared.openChapterTab(from: NSApp.keyWindow)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Reopen Closed Tab") {
                    TabCoordinator.shared.reopenClosedTab(from: NSApp.keyWindow)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Show Previous Tab") {
                    NSApp.keyWindow?.selectPreviousTab(nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Button("Show Next Tab") {
                    NSApp.keyWindow?.selectNextTab(nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                // Purely an NSWindow property, so it needs no view behind it and works from a
                // verse card as well as a reader.
                Button("Keep Window on Top") {
                    guard let window = NSApp.keyWindow else { return }
                    window.level = window.level == .floating ? .normal : .floating
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                // Targets the key window rather than routing, so it stays a no-op in a verse
                // card — spawning a tab just to show a help overlay would be absurd.
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: NSApp.keyWindow)
                }
                .keyboardShortcut("/", modifiers: .command)

                Divider()

                Button("Check for Updates...") {
                    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Send Feedback...") {
                    if let url = URL(string: "https://forms.gle/ggskiDeBvWPaBAt39") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            TabView {
                AppearanceSettingsView()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                KeybindingsSettingsView()
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            }
        }
    }
}

extension Notification.Name {
    static let navigatePreviousChapter = Notification.Name("navigatePreviousChapter")
    static let navigateNextChapter = Notification.Name("navigateNextChapter")
    static let showSearch = Notification.Name("showSearch")
    static let showTableOfContents = Notification.Name("showTableOfContents")
    static let navigateToReference = Notification.Name("navigateToReference")
    static let toggleHistory = Notification.Name("toggleHistory")
    static let toggleBookmark = Notification.Name("toggleBookmark")
    static let navigatePreviousBookmark = Notification.Name("navigatePreviousBookmark")
    static let navigateNextBookmark = Notification.Name("navigateNextBookmark")
    static let navigatePreviousHighlight = Notification.Name("navigatePreviousHighlight")
    static let navigateNextHighlight = Notification.Name("navigateNextHighlight")
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
    static let toggleNotes = Notification.Name("toggleNotes")
    static let scrollPageUp = Notification.Name("scrollPageUp")
    static let scrollPageDown = Notification.Name("scrollPageDown")
    static let checkForUpdates = Notification.Name("checkForUpdates")
    static let toggleReadingTimer = Notification.Name("toggleReadingTimer")
}
