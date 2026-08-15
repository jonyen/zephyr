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

    /// The Spotlight bug: a hit that arrives while the app is in the background lands on a
    /// window whose ContentView has not laid out yet, so it has no idea which window it is in.
    /// Posting straight away reached nobody and the passage was dropped on the floor.
    func testCommandForAWindowWhoseReaderIsNotUpYetWaitsForIt() {
        let window = makeWindow()

        var received: [NSWindow?] = []
        let token = NotificationCenter.default.addObserver(forName: .navigateToReference, object: nil, queue: nil) { note in
            received.append(note.object as? NSWindow)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.route(.navigateToReference, from: window, userInfo: ["book": "Romans", "chapter": 8])
        XCTAssertTrue(received.isEmpty, "nothing can receive this yet")

        coordinator.register(window: window, position: ChapterPosition(bookName: "Genesis", chapterNumber: 1))
        coordinator.drainPendingCommands(for: window)

        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received.first ?? nil === window)
    }

    /// Spotlight can also hand over a reference before the app has any window at all. The
    /// first reader to appear takes it, rather than the reference being lost.
    func testCommandWithNoHostWaitsForTheFirstReader() {
        var received: [NSWindow?] = []
        let token = NotificationCenter.default.addObserver(forName: .navigateToReference, object: nil, queue: nil) { note in
            received.append(note.object as? NSWindow)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.route(.navigateToReference, from: nil, userInfo: ["book": "Romans", "chapter": 8])
        XCTAssertTrue(received.isEmpty, "there is no reader to take it yet")

        let window = makeWindow()
        coordinator.register(window: window, position: ChapterPosition(bookName: "Genesis", chapterNumber: 1))
        coordinator.drainPendingCommands(for: window)

        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received.first ?? nil === window)
    }

    /// The original report: a Spotlight result rewrote every open window. A navigation must
    /// name exactly one target window so the other tabs keep their place.
    func testNavigationNamesASingleTargetWindow() {
        let a = makeWindow()
        let b = makeWindow()
        coordinator.register(window: a, position: ChapterPosition(bookName: "John", chapterNumber: 3))
        coordinator.register(window: b, position: ChapterPosition(bookName: "Acts", chapterNumber: 2))

        var received: [NSWindow?] = []
        let token = NotificationCenter.default.addObserver(forName: .navigateToReference, object: nil, queue: nil) { note in
            received.append(note.object as? NSWindow)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        coordinator.route(.navigateToReference, from: b, userInfo: ["book": "Romans", "chapter": 8])

        XCTAssertEqual(received.count, 1)
        XCTAssertTrue(received.first ?? nil === b)
        XCTAssertNotNil(received.first ?? nil, "a nil target would be taken by every window")
    }

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
