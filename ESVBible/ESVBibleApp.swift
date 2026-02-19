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
        NotificationCenter.default.post(
            name: .navigateToReference,
            object: nil,
            userInfo: userInfo
        )
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

    init() {
        SpotlightIndexer.indexIfNeeded()
    }

    var body: some Scene {
        WindowGroup(for: ChapterPosition.self) { $position in
            ContentView(initialPosition: position.wrappedValue)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Search for Passage") {
                    NotificationCenter.default.post(name: .showSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Go to Previous Chapter") {
                    NotificationCenter.default.post(name: .navigatePreviousChapter, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Go to Next Chapter") {
                    NotificationCenter.default.post(name: .navigateNextChapter, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                Button("Table of Contents") {
                    NotificationCenter.default.post(name: .showTableOfContents, object: nil)
                }

                Button("Toggle History") {
                    NotificationCenter.default.post(name: .toggleHistory, object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)

                Button("Toggle Notes") {
                    NotificationCenter.default.post(name: .toggleNotes, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Toggle Bookmark") {
                    NotificationCenter.default.post(name: .toggleBookmark, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Previous Bookmark") {
                    NotificationCenter.default.post(name: .navigatePreviousBookmark, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

                Button("Next Bookmark") {
                    NotificationCenter.default.post(name: .navigateNextBookmark, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])

                Button("Previous Highlight") {
                    NotificationCenter.default.post(name: .navigatePreviousHighlight, object: nil)
                }
                .keyboardShortcut("{", modifiers: .command)

                Button("Next Highlight") {
                    NotificationCenter.default.post(name: .navigateNextHighlight, object: nil)
                }
                .keyboardShortcut("}", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Reopen Closed Tab") {
                    NotificationCenter.default.post(name: .reopenClosedTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Keep Window on Top") {
                    NotificationCenter.default.post(name: .toggleWindowOnTop, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
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
    static let toggleWindowOnTop = Notification.Name("toggleWindowOnTop")
    static let newTab = Notification.Name("newTab")
    static let reopenClosedTab = Notification.Name("reopenClosedTab")
}
