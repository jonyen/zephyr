import XCTest
@testable import ESVBible

final class PoetryLayoutTests: XCTestCase {

    private func verse(_ number: Int, _ text: String) -> Verse {
        Verse(number: number, text: text)
    }

    // MARK: - Recognizing poetry

    func testVerseWithLineBreakIsPoetry() {
        XCTAssertTrue(PoetryLayout.isPoetry("He makes me lie down in green pastures.\nHe leads me beside still waters."))
    }

    func testSingleLineVerseIsNotPoetry() {
        XCTAssertFalse(PoetryLayout.isPoetry("The Lord is my shepherd; I shall not want."))
    }

    // MARK: - Splitting lines

    func testUnbrokenVerseIsOneFlushLine() {
        let lines = PoetryLayout.lines(in: "The Lord is my shepherd.")
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].indent, 0)
        XCTAssertEqual(lines[0].range, NSRange(location: 0, length: 24))
    }

    func testIndentLevelComesFromLeadingSpaces() {
        let lines = PoetryLayout.lines(in: "Your kingdom come,\n    your will be done,\n        on earth.")
        XCTAssertEqual(lines.map(\.indent), [0, 1, 2])
    }

    func testLineRangesCoverTheRawTextIncludingIndentSpaces() {
        let text = "He restores my soul.\nHe leads me in paths of righteousness\n    for his name's sake."
        let ns = text as NSString
        let lines = PoetryLayout.lines(in: text)
        XCTAssertEqual(lines.map { ns.substring(with: $0.range) }, [
            "He restores my soul.",
            "He leads me in paths of righteousness",
            "    for his name's sake.",
        ])
    }

    func testLineTextDropsTheIndentSpaces() {
        let lines = PoetryLayout.lines(in: "Your kingdom come,\n    your will be done,")
        XCTAssertEqual(lines.map(\.text), ["Your kingdom come,", "your will be done,"])
    }

    // MARK: - Laying out a chapter

    func testConsecutiveProseVersesStayProse() {
        let layout = PoetryLayout.layout([verse(1, "In the beginning,"), verse(2, "The earth was without form.")])
        XCTAssertEqual(layout.map(\.isPoetry), [false, false])
    }

    func testEveryVerseOfAPoemIsPoetry() {
        // Psalm 23:1-3 — verse 1 carries no line break of its own
        let layout = PoetryLayout.layout([
            verse(1, "The Lord is my shepherd; I shall not want."),
            verse(2, "He makes me lie down in green pastures.\nHe leads me beside still waters."),
            verse(3, "He restores my soul.\nHe leads me in paths of righteousness\n    for his name's sake."),
        ])
        XCTAssertEqual(layout.map(\.isPoetry), [true, true, true])
    }

    func testUnbrokenVerseBetweenPoemVersesIsPoetry() {
        // Matthew 6:10-12 — verse 11 is one unbroken petition
        let layout = PoetryLayout.layout([
            verse(10, "Your kingdom come,\n    your will be done,"),
            verse(11, "Give us this day our daily bread,"),
            verse(12, "and forgive us our debts,\n    as we also have forgiven our debtors."),
        ])
        XCTAssertEqual(layout.map(\.isPoetry), [true, true, true])
    }

    func testProseFollowingAPoemStaysProse() {
        // Matthew 6:13-15 — the prose paragraph resumes at 14
        let layout = PoetryLayout.layout([
            verse(13, "And lead us not into temptation,\n    but deliver us from evil."),
            verse(14, "For if you forgive others their trespasses,"),
            verse(15, "but if you do not forgive others their trespasses,"),
        ])
        XCTAssertEqual(layout.map(\.isPoetry), [true, false, false])
    }

    func testOmittedVersesAreDropped() {
        let layout = PoetryLayout.layout([
            verse(43, "where their worm does not die."),
            verse(44, ""),
            verse(45, "And if your foot causes you to sin."),
        ])
        XCTAssertEqual(layout.map(\.verse.number), [43, 45])
    }

    func testOmittedVerseDoesNotSplitAPoem() {
        let layout = PoetryLayout.layout([
            verse(1, "Praise the Lord!\n    Praise God in his sanctuary;"),
            verse(2, ""),
            verse(3, "Praise him with trumpet sound;\n    praise him with lute and harp!"),
        ])
        XCTAssertEqual(layout.map(\.isPoetry), [true, true])
    }

    func testEmptyChapterLaysOutToNothing() {
        XCTAssertTrue(PoetryLayout.layout([]).isEmpty)
    }

    // MARK: - Verse separators

    func testProseVersesAreJoinedBySpaces() {
        let layout = PoetryLayout.layout([verse(1, "In the beginning,"), verse(2, "The earth was without form.")])
        XCTAssertEqual(layout.map(\.separator), [" ", ""])
    }

    func testPoemVersesAreJoinedByLineBreaks() {
        let layout = PoetryLayout.layout([
            verse(1, "The Lord is my shepherd; I shall not want."),
            verse(2, "He makes me lie down in green pastures.\nHe leads me beside still waters."),
        ])
        XCTAssertEqual(layout.map(\.separator), ["\n", ""])
    }

    func testProseBreaksOntoItsOwnLineAfterAPoem() {
        let layout = PoetryLayout.layout([
            verse(13, "And lead us not into temptation,\n    but deliver us from evil."),
            verse(14, "For if you forgive others their trespasses,"),
            verse(15, "but if you do not forgive others their trespasses,"),
        ])
        XCTAssertEqual(layout.map(\.separator), ["\n", " ", ""])
    }

    func testProseBreaksBeforeAPoemBegins() {
        let layout = PoetryLayout.layout([
            verse(8, "Do not be like them."),
            verse(9, "Pray then like this:\n\u{201C}Our Father in heaven,"),
        ])
        XCTAssertEqual(layout.map(\.separator), ["\n", ""])
    }

    func testSeparatorsAreExactlyOneCharacterSoVerseOffsetsAreUnchanged() {
        let layout = PoetryLayout.layout([
            verse(1, "The Lord is my shepherd; I shall not want."),
            verse(2, "He makes me lie down in green pastures.\nHe leads me beside still waters."),
            verse(3, "He restores my soul."),
        ])
        XCTAssertEqual(layout.dropLast().map { $0.separator.count }, [1, 1])
    }
}
