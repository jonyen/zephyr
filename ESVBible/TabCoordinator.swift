import AppKit
import SwiftUI

/// Creates reading tabs and remembers where each one is parked.
///
/// Tab windows are plain `NSWindow`s hosting either a `ContentView` (a chapter) or a
/// `VerseRangeView` (a verse lookup). Tab creation lives here rather than inside a view
/// because only `ContentView` can answer for its own window: when a verse-range tab was
/// frontmost, a window-targeted New Tab command reached nobody and silently did nothing.
@MainActor
final class TabCoordinator {
    static let shared = TabCoordinator()

    private static let fallbackPosition = ChapterPosition(bookName: "Genesis", chapterNumber: 1)

    /// What a tab can service. A verse card has no reading pane, so reader commands have to be
    /// sent somewhere else.
    enum Kind {
        case reader
        case verseRange
    }

    /// Windows are held weakly so a closed tab can't leak, and so a later window that reuses
    /// its address can't inherit its position.
    private struct Entry {
        weak var window: NSWindow?
        var position: ChapterPosition
        var kind: Kind
    }

    private var entries: [Entry] = []
    private var lastKnownPosition: ChapterPosition?

    /// Commands waiting for a reader tab that is still being built. A nil window means the
    /// command has no target yet — it goes to whichever reader reports in first.
    private var pendingCommands: [(window: NSWindow?, command: Notification.Name, userInfo: [AnyHashable: Any]?)] = []

    // MARK: - Position tracking

    func register(window: NSWindow, position: ChapterPosition, kind: Kind = .reader) {
        entries.removeAll { $0.window == nil || $0.window === window }
        entries.append(Entry(window: window, position: position, kind: kind))
        lastKnownPosition = position
    }

    /// Whether `window` has a reading pane that can service reader commands. Unknown windows
    /// count as readers: the app's original WindowGroup window registers only once its
    /// ContentView has laid out, and it must not be mistaken for a verse card before then.
    func isReader(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        guard let entry = entries.first(where: { $0.window === window }) else { return true }
        return entry.kind == .reader
    }

    /// Whether `window`'s reader has reported in. A window exists as an `NSWindow` well before
    /// its `ContentView` knows which window it lives in, and until then it can receive nothing.
    private func hasReported(_ window: NSWindow) -> Bool {
        entries.contains { $0.window === window }
    }

    /// The frontmost window that already has a reader behind it.
    private func frontmostReader() -> NSWindow? {
        NSApp.orderedWindows.first { window in
            entries.contains { $0.window === window && $0.kind == .reader }
        }
    }

    func unregister(window: NSWindow) {
        entries.removeAll { $0.window == nil || $0.window === window }
    }

    /// The chapter a tab spawned from `window` should open to. Always resolves to something:
    /// the window's own position, else the last position seen anywhere, else Genesis 1.
    func position(for window: NSWindow?) -> ChapterPosition {
        if let window, let entry = entries.first(where: { $0.window === window }) {
            return entry.position
        }
        return lastKnownPosition ?? Self.fallbackPosition
    }

    // MARK: - Routing commands

    /// Sends a reader command to the frontmost tab, or to a new reader tab when the frontmost
    /// one is a verse card and has no reading pane to act on.
    ///
    /// A command is always addressed to exactly one window. It is never broadcast: an
    /// unaddressed notification is taken by every open tab, which is how a Spotlight result
    /// used to rewrite the whole app at once.
    func route(_ command: Notification.Name, from host: NSWindow?, userInfo: [AnyHashable: Any]? = nil) {
        if let host, isReader(host) {
            // Spotlight and the URL scheme arrive with the app in the background, and macOS
            // hands them a window whose reader has not laid out yet. Posting now would reach
            // nobody, so the command waits for that window rather than being dropped.
            if hasReported(host) {
                NotificationCenter.default.post(name: command, object: host, userInfo: userInfo)
            } else {
                enqueuePendingCommand(command, for: host, userInfo: userInfo)
            }
            return
        }
        if host == nil {
            // No key window: the app was launched or woken straight into this command. Give it
            // to the frontmost reader, or to the first one to appear if there is none yet.
            if let target = frontmostReader() {
                NotificationCenter.default.post(name: command, object: target, userInfo: userInfo)
            } else {
                pendingCommands.append((nil, command, userInfo))
            }
            return
        }
        guard let window = openChapterTab(from: host, at: position(for: host)) else { return }
        enqueuePendingCommand(command, for: window, userInfo: userInfo)
    }

    /// Holds a command until `window`'s reader is on screen to receive it.
    func enqueuePendingCommand(_ command: Notification.Name, for window: NSWindow, userInfo: [AnyHashable: Any]? = nil) {
        pendingCommands.append((window, command, userInfo))
    }

    /// Runs anything that was waiting on this window, now that its reader is on screen —
    /// including commands that were still looking for any reader at all.
    /// Called by `ContentView` once it knows which window it lives in.
    func drainPendingCommands(for window: NSWindow) {
        let pending = pendingCommands.filter { $0.window === window || $0.window == nil }
        pendingCommands.removeAll { $0.window === window || $0.window == nil }
        for item in pending {
            NotificationCenter.default.post(name: item.command, object: window, userInfo: item.userInfo)
        }
    }

    // MARK: - Opening tabs

    @discardableResult
    func openChapterTab(from host: NSWindow?) -> NSWindow? {
        openChapterTab(from: host, at: position(for: host))
    }

    @discardableResult
    func openChapterTab(from host: NSWindow?, at position: ChapterPosition) -> NSWindow? {
        guard let host = host ?? NSApp.keyWindow else { return nil }
        // Build the window directly instead of going through SwiftUI's openWindow(value:).
        // openWindow deduplicates by ChapterPosition value — if the same chapter is already
        // open it focuses the existing window rather than creating a new one, so
        // addTabbedWindow is never called. NSHostingController gives a fresh NSWindow every
        // time with no race.
        let controller = NSHostingController(rootView: ContentView(initialPosition: position))
        return addTab(hosting: controller,
                      title: "\(position.bookName) \(position.chapterNumber)",
                      to: host)
    }

    func reopenClosedTab(from host: NSWindow?) {
        guard let position = ClosedTabsStack.shared.pop() else { return }
        openChapterTab(from: host, at: position)
    }

    func openVerseRangeTab(from host: NSWindow?, references: [BibleReference], bibleStore: BibleStore) {
        guard let host = host ?? NSApp.keyWindow, let first = references.first else { return }
        let controller = NSHostingController(rootView: VerseRangeView(references: references, bibleStore: bibleStore))
        let window = addTab(hosting: controller,
                            title: references.map(\.displayString).joined(separator: " \u{00B7} "),
                            to: host)
        // A verse-range tab has no ContentView to report a position, so record the
        // reference's own chapter — that's what a new tab spawned from here should open.
        register(window: window,
                 position: ChapterPosition(bookName: bibleStore.findBook(first.book)?.name ?? first.book,
                                           chapterNumber: first.chapter),
                 kind: .verseRange)
    }

    @discardableResult
    private func addTab(hosting controller: NSViewController, title: String, to host: NSWindow) -> NSWindow {
        // NSWindow(contentViewController:) mirrors the controller's title, and SwiftUI only
        // forwards `navigationTitle` into that for some hierarchies — VerseRangeView's never
        // arrives, which left the tab labelled "Untitled". Setting it here covers every tab,
        // and ContentView's navigationTitle still takes over as the reader scrolls.
        controller.title = title
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.setContentSize(NSSize(width: max(host.frame.width, 400), height: max(host.frame.height, 500)))
        window.styleMask = host.styleMask
        window.tabbingMode = .preferred
        window.tabbingIdentifier = host.tabbingIdentifier
        host.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
