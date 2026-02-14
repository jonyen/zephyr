import SwiftUI
import CoreSpotlight

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let parsed = SpotlightIndexer.parseIdentifier(identifier) else {
            return false
        }
        NotificationCenter.default.post(
            name: .navigateToReference,
            object: nil,
            userInfo: [
                "book": parsed.book,
                "chapter": parsed.chapter,
                "verse": parsed.verse as Any
            ]
        )
        return true
    }
}

@main
struct ESVBibleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        SpotlightIndexer.indexIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                .keyboardShortcut("t", modifiers: .command)

                Button("Toggle History") {
                    NotificationCenter.default.post(name: .toggleHistory, object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)
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
}
