import XCTest
@testable import ESVBible

@MainActor
final class ClosedTabsStackTests: XCTestCase {
    var stack: ClosedTabsStack!

    override func setUp() {
        super.setUp()
        stack = ClosedTabsStack(defaults: UserDefaults(suiteName: "ClosedTabsStackTests")!)
        stack.clear()
    }

    override func tearDown() {
        stack.clear()
        super.tearDown()
    }

    func testPopFromEmptyStackReturnsNil() {
        XCTAssertNil(stack.pop())
    }

    func testPushAndPop() {
        let pos = ChapterPosition(bookName: "John", chapterNumber: 3)
        stack.push(pos)
        let popped = stack.pop()
        XCTAssertEqual(popped?.bookName, "John")
        XCTAssertEqual(popped?.chapterNumber, 3)
    }

    func testPopIsLIFO() {
        stack.push(ChapterPosition(bookName: "Genesis", chapterNumber: 1))
        stack.push(ChapterPosition(bookName: "John", chapterNumber: 3))
        XCTAssertEqual(stack.pop()?.bookName, "John")
        XCTAssertEqual(stack.pop()?.bookName, "Genesis")
    }

    func testCapAt20() {
        for i in 1...25 {
            stack.push(ChapterPosition(bookName: "Psalm", chapterNumber: i))
        }
        var count = 0
        while stack.pop() != nil { count += 1 }
        XCTAssertEqual(count, 20)
    }

    func testPersistsAcrossInstances() {
        let pos = ChapterPosition(bookName: "Romans", chapterNumber: 8)
        stack.push(pos)
        let stack2 = ClosedTabsStack(defaults: UserDefaults(suiteName: "ClosedTabsStackTests")!)
        XCTAssertEqual(stack2.pop()?.bookName, "Romans")
    }
}
