import SwiftUI

@main
struct SparkApp: App {
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
            }
        }
    }
}

extension Notification.Name {
    static let navigatePreviousChapter = Notification.Name("navigatePreviousChapter")
    static let navigateNextChapter = Notification.Name("navigateNextChapter")
    static let showSearch = Notification.Name("showSearch")
    static let showTableOfContents = Notification.Name("showTableOfContents")
}
