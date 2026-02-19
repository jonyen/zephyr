import XCTest
@testable import ESVBible

final class ChapterPositionTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let position = ChapterPosition(bookName: "John", chapterNumber: 3)
        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(ChapterPosition.self, from: data)
        XCTAssertEqual(decoded.bookName, "John")
        XCTAssertEqual(decoded.chapterNumber, 3)
    }
}
