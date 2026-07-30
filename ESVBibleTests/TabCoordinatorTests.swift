import XCTest
import AppKit
@testable import ESVBible

@MainActor
final class TabCoordinatorTests: XCTestCase {
    private var coordinator: TabCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = TabCoordinator()
    }

    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                 styleMask: [.titled], backing: .buffered, defer: true)
    }

    func testUnknownWindowWithNoHistoryFallsBackToGenesis1() {
        XCTAssertEqual(coordinator.position(for: makeWindow()),
                       ChapterPosition(bookName: "Genesis", chapterNumber: 1))
    }

    func testRegisteredWindowReturnsItsPosition() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 15))
        XCTAssertEqual(coordinator.position(for: window),
                       ChapterPosition(bookName: "John", chapterNumber: 15))
    }

    /// The bug: a verse-range tab never registers a reading position, so New Tab found no
    /// answer for the key window and silently did nothing. Any window must resolve to
    /// *something* — here, the most recent position seen anywhere in the app.
    func testUnregisteredWindowFallsBackToLastKnownPosition() {
        let registered = makeWindow()
        coordinator.register(window: registered, position: ChapterPosition(bookName: "Romans", chapterNumber: 8))

        let verseRangeWindow = makeWindow()
        XCTAssertEqual(coordinator.position(for: verseRangeWindow),
                       ChapterPosition(bookName: "Romans", chapterNumber: 8))
    }

    func testNilWindowFallsBackToLastKnownPosition() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "Acts", chapterNumber: 2))
        XCTAssertEqual(coordinator.position(for: nil),
                       ChapterPosition(bookName: "Acts", chapterNumber: 2))
    }

    func testRegisterOverwritesPreviousPositionForSameWindow() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 1))
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3))
        XCTAssertEqual(coordinator.position(for: window),
                       ChapterPosition(bookName: "John", chapterNumber: 3))
    }

    func testUnregisterDropsTheWindowButKeepsLastKnown() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "Psalms", chapterNumber: 23))
        coordinator.unregister(window: window)

        // The window's own entry is gone, but the app still remembers where the reader was.
        XCTAssertEqual(coordinator.position(for: makeWindow()),
                       ChapterPosition(bookName: "Psalms", chapterNumber: 23))
    }

    // MARK: - Tab kinds

    func testUnknownWindowCountsAsReader() {
        // The app's original WindowGroup window registers only once its ContentView lays out;
        // until then it must not be mistaken for a verse card.
        XCTAssertTrue(coordinator.isReader(makeWindow()))
    }

    func testNilWindowIsNotAReader() {
        XCTAssertFalse(coordinator.isReader(nil))
    }

    func testReaderTabIsAReader() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3), kind: .reader)
        XCTAssertTrue(coordinator.isReader(window))
    }

    func testVerseRangeTabIsNotAReader() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3), kind: .verseRange)
        XCTAssertFalse(coordinator.isReader(window))
    }

    func testReRegisteringChangesKind() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3), kind: .verseRange)
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3), kind: .reader)
        XCTAssertTrue(coordinator.isReader(window))
    }

    // MARK: - Command routing

    func testRoutingToAReaderPostsImmediatelyToThatWindow() {
        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "John", chapterNumber: 3), kind: .reader)

        var received: [NSWindow?] = []
        let token = NotificationCenter.default.addObserver(forName: .toggleHistory, object: nil, queue: nil) { note in
            received.append(note.object as? NSWindow)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.route(.toggleHistory, from: window)

        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received.first ?? nil === window)
    }

    func testDrainingDeliversPendingCommandsOnce() {
        let window = makeWindow()
        coordinator.enqueuePendingCommand(.showSearch, for: window)

        var received: [NSWindow?] = []
        let token = NotificationCenter.default.addObserver(forName: .showSearch, object: nil, queue: nil) { note in
            received.append(note.object as? NSWindow)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.drainPendingCommands(for: window)
        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received.first ?? nil === window)

        // A second drain must not replay it.
        coordinator.drainPendingCommands(for: window)
        XCTAssertEqual(received.count, 1)
    }

    func testDrainingOnlyDeliversCommandsForThatWindow() {
        let a = makeWindow()
        let b = makeWindow()
        coordinator.enqueuePendingCommand(.showSearch, for: a)
        coordinator.enqueuePendingCommand(.toggleNotes, for: b)

        var receivedSearch = 0
        let token = NotificationCenter.default.addObserver(forName: .showSearch, object: nil, queue: nil) { _ in
            receivedSearch += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.drainPendingCommands(for: b)
        XCTAssertEqual(receivedSearch, 0, "b's drain must not fire a's pending command")

        coordinator.drainPendingCommands(for: a)
        XCTAssertEqual(receivedSearch, 1)
    }

    /// Windows are keyed by identity, so a freshly allocated window that happens to reuse a
    /// closed window's address must not inherit its position.
    func testEachWindowTracksItsOwnPosition() {
        let a = makeWindow()
        let b = makeWindow()
        coordinator.register(window: a, position: ChapterPosition(bookName: "Genesis", chapterNumber: 5))
        coordinator.register(window: b, position: ChapterPosition(bookName: "Exodus", chapterNumber: 20))

        XCTAssertEqual(coordinator.position(for: a), ChapterPosition(bookName: "Genesis", chapterNumber: 5))
        XCTAssertEqual(coordinator.position(for: b), ChapterPosition(bookName: "Exodus", chapterNumber: 20))
    }
}
